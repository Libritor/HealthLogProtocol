import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../core/config/rpc_config.dart';
import '../../domain/models/baseline_models.dart';
import 'baseline_anchor_service.dart';
import 'baseline_hashing.dart';

/// In-memory baseline anchoring for offline demos and fresh-clone review.
/// Identical UX to the devnet service; transaction signatures are synthetic.
class MockBaselineAnchorService implements BaselineAnchorService {
  static const _uuid = Uuid();
  static final _rng = Random();

  final BaselineHashing _hashing;

  MockBaselineAnchorService(this._hashing);

  @override
  final RpcConfig rpcConfig = const RpcConfig(
    httpUrl: 'mock://in-memory',
    wsUrl: 'mock://in-memory',
    network: 'mock',
  );

  @override
  String get modeLabel => 'Mock (offline)';

  String? _wallet;

  @override
  String? get connectedWallet => _wallet;

  /// txSignature -> committed envelope (privacy-safe, no parameters).
  final Map<String, Map<String, dynamic>> _commitments = {};
  final Set<String> _revokedBaselineIds = {};
  final Map<String, String> _txToBaselineId = {};

  @override
  Future<String> connectWallet() async {
    // 32 hex chars after stripping dashes — a stable, wallet-like mock address.
    _wallet ??= 'Mock${_uuid.v4().replaceAll('-', '')}';
    return _wallet!;
  }

  String _fakeSig() {
    const chars =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    return List.generate(88, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  @override
  Future<BaselineCommitment> anchorBaseline(WearableBaseline baseline) async {
    await connectWallet();
    final manifest = BaselineManifest(
      owner: baseline.ownerWallet ?? _wallet!,
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
    BaselineHashing.assertEnvelopeSafe(envelope); // privacy gate before "send"

    final sig = _fakeSig();
    _commitments[sig] = envelope;
    _txToBaselineId[sig] = baseline.baselineId;

    return BaselineCommitment(
      baseline: baseline.copyWith(
        ownerWallet: manifest.owner,
        onchainStatus: BaselineOnchainStatus.anchored,
        onchainTxSignature: sig,
      ),
      txSignature: sig,
      explorerUrl: 'mock://tx/$sig',
    );
  }

  @override
  Future<String> revokeBaseline({required String baselineId}) async {
    _revokedBaselineIds.add(baselineId);
    return _fakeSig();
  }

  @override
  Future<BaselineVerification> verifyBaseline({
    required String txSignature,
    required Map<String, dynamic> candidateParameters,
    String? expectedOwner,
  }) async {
    final env = _commitments[txSignature];
    if (env == null) {
      return const BaselineVerification(
        foundOnchain: false,
        isBaselineCommitment: false,
        hashMatches: false,
        ownerMatches: false,
        withinHorizon: false,
        noRawParameters: true,
        errorMessage: 'No commitment found for this signature (mock).',
      );
    }
    final localHash = _hashing.hashParameters(candidateParameters);
    final validUntil = env['validUntil'] as String?;
    final fresh =
        validUntil == null || DateTime.parse(validUntil).isAfter(DateTime.now());
    final baselineId = _txToBaselineId[txSignature];
    final revoked = baselineId != null && _revokedBaselineIds.contains(baselineId);

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

  bool _looksRaw(Map<String, dynamic> env) {
    for (final k in BaselineHashing.forbiddenPayloadKeys) {
      final v = env[k];
      if (v is List || v is Map) return true;
    }
    return false;
  }
}
