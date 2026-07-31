import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/rpc_config.dart';
import '../../domain/models/baseline_models.dart';
import 'baseline_anchor_service.dart';
import 'baseline_hashing.dart';

/// Real Solana baseline anchoring via SPL Memo transactions, over any RPC
/// endpoint given by [RpcConfig]. Point [RpcConfig] at RPC Fast to use it as the
/// mainnet write/verify rail; the default is public devnet (the free demo).
///
/// Shares the persisted devnet wallet seed with `DevnetSolanaService`, so the
/// same funded keypair signs both session commits and baseline anchors.
class DevnetBaselineAnchorService implements BaselineAnchorService {
  static const _uuid = Uuid();
  static const _walletSeedKey = 'healthlog_devnet_wallet_seed';
  static const _hdPath = "m/44'/501'/0'/0'";
  static const _minBalanceLamports = 5000000;
  static final _rng = Random.secure();

  final FlutterSecureStorage _secureStorage;
  final BaselineHashing _hashing;

  @override
  final RpcConfig rpcConfig;

  DevnetBaselineAnchorService({
    required BaselineHashing hashing,
    RpcConfig? rpcConfig,
    FlutterSecureStorage? secureStorage,
  })  : _hashing = hashing,
        rpcConfig = rpcConfig ?? RpcConfig.fromEnvironment(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  SolanaClient? _client;
  Ed25519HDKeyPair? _keypair;
  String? _walletAddress;

  // txSignature -> committed envelope (privacy-safe, no parameters).
  final Map<String, Map<String, dynamic>> _commitments = {};
  final Set<String> _revokedBaselineIds = {};
  final Map<String, String> _txToBaselineId = {};

  @override
  String get modeLabel => rpcConfig.displayLabel;

  @override
  String? get connectedWallet => _walletAddress;

  SolanaClient _getClient() {
    _client ??= SolanaClient(
      rpcUrl: Uri.parse(rpcConfig.httpUrl),
      websocketUrl: Uri.parse(rpcConfig.wsUrl),
    );
    return _client!;
  }

  @override
  Future<String> connectWallet() async {
    final stored = await _secureStorage.read(key: _walletSeedKey);
    final List<int> seed;
    if (stored != null) {
      seed = base64Decode(stored);
    } else {
      seed = List<int>.generate(32, (_) => _rng.nextInt(256));
      await _secureStorage.write(key: _walletSeedKey, value: base64Encode(seed));
    }
    _keypair = await Ed25519HDKeyPair.fromSeedWithHdPath(
      seed: seed,
      hdPath: _hdPath,
    );
    _walletAddress = _keypair!.address;
    // Only devnet has a faucet; on mainnet the user funds the wallet.
    if (!rpcConfig.isMainnet) unawaited(_ensureFunded());
    return _walletAddress!;
  }

  Future<int> _getBalance() async {
    if (_keypair == null) return 0;
    try {
      final balance = await _getClient().rpcClient.getBalance(_walletAddress!);
      return balance.value;
    } catch (e) {
      debugPrint('[HealthLog.Baseline] getBalance failed: $e');
      return 0;
    }
  }

  Future<void> _ensureFunded() async {
    if (_keypair == null) return;
    if (await _getBalance() >= _minBalanceLamports) return;
    try {
      await _getClient().requestAirdrop(
        address: Ed25519HDPublicKey.fromBase58(_walletAddress!),
        lamports: 1000000000,
        commitment: Commitment.confirmed,
      );
      for (var i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (await _getBalance() >= _minBalanceLamports) return;
      }
    } catch (e) {
      debugPrint('[HealthLog.Baseline] airdrop failed (rate-limited?): $e');
    }
  }

  void _requireWallet() {
    if (_walletAddress == null || _keypair == null) {
      throw StateError('Wallet not connected. Call connectWallet() first.');
    }
  }

  Future<String> _sendMemo(String memoText) async {
    _requireWallet();
    if (!rpcConfig.isMainnet) await _ensureFunded();
    try {
      final signature = await _getClient().sendAndConfirmTransaction(
        message: Message.only(
          MemoInstruction(signers: [_keypair!.publicKey], memo: memoText),
        ),
        signers: [_keypair!],
        commitment: Commitment.confirmed,
      );
      debugPrint('[HealthLog.Baseline] anchored. Tx: $signature');
      return signature;
    } catch (e) {
      debugPrint('[HealthLog.Baseline] sendMemo failed: $e');
      return 'devnet_fallback_${_uuid.v4().replaceAll('-', '')}';
    }
  }

  @override
  Future<BaselineCommitment> anchorBaseline(WearableBaseline baseline) async {
    _requireWallet();
    final manifest = BaselineManifest(
      owner: _walletAddress!,
      signal: baseline.signalType,
      model: baseline.model,
      modelVersion: baseline.modelVersion,
      featureSchema: baseline.featureSchema,
      featureSchemaHash: baseline.featureSchemaHash,
      baselineHash: baseline.baselineHash,
      dims: baseline.dims,
      recordedSeconds: baseline.recordedSeconds,
      validUntil: baseline.validUntil,
      ts: baseline.createdAt,
    );
    final envelope = manifest.toEnvelope();
    BaselineHashing.assertEnvelopeSafe(envelope); // privacy gate before send

    final sig = await _sendMemo(jsonEncode(envelope));
    _commitments[sig] = envelope;
    _txToBaselineId[sig] = baseline.baselineId;

    return BaselineCommitment(
      baseline: baseline.copyWith(
        ownerWallet: _walletAddress,
        onchainStatus: BaselineOnchainStatus.anchored,
        onchainTxSignature: sig,
      ),
      txSignature: sig,
      explorerUrl: rpcConfig.explorerTxUrl(sig),
    );
  }

  @override
  Future<String> revokeBaseline({required String baselineId}) async {
    _requireWallet();
    _revokedBaselineIds.add(baselineId);
    return _sendMemo(jsonEncode({
      'type': 'baseline_revoke',
      'owner': _walletAddress,
      'baselineId': baselineId,
      'ts': DateTime.now().toIso8601String(),
    }));
  }

  @override
  Future<BaselineVerification> verifyBaseline({
    required String txSignature,
    required Map<String, dynamic> candidateParameters,
    String? expectedOwner,
  }) async {
    // Prefer the on-chain envelope; fall back to the local commitment cache.
    final env = await _readEnvelope(txSignature) ?? _commitments[txSignature];
    if (env == null) {
      return const BaselineVerification(
        foundOnchain: false,
        isBaselineCommitment: false,
        hashMatches: false,
        ownerMatches: false,
        withinHorizon: false,
        noRawParameters: true,
        errorMessage: 'Transaction not found or unconfirmed.',
      );
    }

    final localHash = _hashing.hashParameters(candidateParameters);
    final validUntil = env['validUntil'] as String?;
    final fresh = validUntil == null ||
        DateTime.parse(validUntil).isAfter(DateTime.now());
    final baselineId = _txToBaselineId[txSignature];
    final revoked =
        baselineId != null && _revokedBaselineIds.contains(baselineId);

    return BaselineVerification(
      foundOnchain: true,
      isBaselineCommitment: env['type'] == 'baseline_commitment' && !revoked,
      hashMatches: env['baselineHash'] == localHash,
      ownerMatches: expectedOwner == null || env['owner'] == expectedOwner,
      withinHorizon: fresh,
      noRawParameters: !_looksRaw(env),
      errorMessage: revoked ? 'Baseline was revoked.' : null,
    );
  }

  /// Best-effort read of the memo envelope from the transaction log. Returns
  /// null on any RPC/parse failure (caller falls back to the local cache).
  Future<Map<String, dynamic>?> _readEnvelope(String sig) async {
    if (sig.startsWith('devnet_fallback_')) return null;
    try {
      // Default encoding is fine: memo text surfaces in meta.logMessages
      // regardless. (Encoding is not re-exported by package:solana/solana.dart.)
      final details = await _getClient().rpcClient.getTransaction(
        sig,
        commitment: Commitment.confirmed,
      );
      final logs = details?.meta?.logMessages ?? const <String>[];
      for (final line in logs) {
        final match = RegExp(r'Memo \(len \d+\): "(.*)"$').firstMatch(line);
        if (match != null) {
          final decoded = jsonDecode(match.group(1)!.replaceAll(r'\"', '"'));
          if (decoded is Map<String, dynamic>) return decoded;
        }
      }
    } catch (e) {
      debugPrint('[HealthLog.Baseline] readEnvelope failed: $e');
    }
    return null;
  }

  bool _looksRaw(Map<String, dynamic> env) {
    for (final k in BaselineHashing.forbiddenPayloadKeys) {
      final v = env[k];
      if (v is List || v is Map) return true;
    }
    return false;
  }
}
