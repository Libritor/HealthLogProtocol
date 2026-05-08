import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../domain/models/solana_models.dart';
import 'solana_consent_service.dart';

/// In-memory mock of the Solana consent service.
/// Generates fake transaction signatures and stores all state locally.
/// UI must clearly show "Mock Mode" when this implementation is active.
class MockSolanaService implements SolanaConsentService {
  static const _uuid = Uuid();
  static final _rng = Random.secure();

  String? _walletAddress;

  final Map<String, _SessionCommitment> _commitments = {};
  final Map<String, ConsentGrant> _grants = {};
  final Map<String, DataAccessToken> _tokens = {};
  final List<AccessLog> _accessLogs = [];

  @override
  SolanaMode get mode => SolanaMode.mock;

  @override
  String? get connectedWallet => _walletAddress;

  @override
  Future<String> connectWallet() async {
    await _simulateLatency();
    _walletAddress = _generateMockWallet();
    return _walletAddress!;
  }

  @override
  Future<String> commitSession({
    required String manifestHash,
    required String rawFileHash,
    List<String> metadataTags = const [],
  }) async {
    _requireWallet();
    await _simulateLatency();
    final txSig = _generateMockTxSignature();
    _commitments[manifestHash] = _SessionCommitment(
      ownerWallet: _walletAddress!,
      manifestHash: manifestHash,
      rawFileHash: rawFileHash,
      txSignature: txSig,
      metadataTags: metadataTags,
      createdAt: DateTime.now(),
    );
    return txSig;
  }

  @override
  Future<ConsentGrantResult> grantAccess({
    required String sessionId,
    required String manifestHash,
    required String recipientWallet,
    required ConsentScope scope,
    required DateTime expiresAt,
    required ConsentPurpose purpose,
  }) async {
    _requireWallet();
    await _simulateLatency();
    final txSig = _generateMockTxSignature();
    final now = DateTime.now();
    final grantId = _uuid.v4();
    final tokenId = _uuid.v4();

    final grant = ConsentGrant(
      grantId: grantId,
      sessionId: sessionId,
      ownerWallet: _walletAddress!,
      recipientWallet: recipientWallet,
      scope: scope,
      purpose: purpose,
      expiresAt: expiresAt,
      onchainTxSignature: txSig,
      createdAt: now,
    );

    final token = DataAccessToken(
      tokenId: tokenId,
      grantId: grantId,
      sessionId: sessionId,
      recipientWallet: recipientWallet,
      scope: scope,
      manifestHash: manifestHash,
      expiresAt: expiresAt,
      issuedAt: now,
    );

    _grants[grantId] = grant;
    _tokens[grantId] = token;

    _accessLogs.add(AccessLog(
      accessId: _uuid.v4(),
      grantId: grantId,
      sessionId: sessionId,
      recipientWallet: recipientWallet,
      accessedAt: now,
      accessType: 'grant_created',
      verifiedOnchain: false,
      notes: 'Access token issued: ${scope.displayName}',
    ));

    return ConsentGrantResult(
      grant: grant,
      token: token,
      txSignature: txSig,
    );
  }

  @override
  Future<String> revokeAccess({required String grantId}) async {
    _requireWallet();
    await _simulateLatency();

    final grant = _grants[grantId];
    if (grant == null) throw StateError('Grant not found: $grantId');

    final txSig = _generateMockTxSignature();
    final now = DateTime.now();

    _grants[grantId] = grant.copyWith(
      revoked: true,
      revokedAt: now,
      onchainTxSignature: txSig,
    );

    final token = _tokens[grantId];
    if (token != null) {
      _tokens[grantId] = token.copyWith(revoked: true, revokedAt: now);
    }

    _accessLogs.add(AccessLog(
      accessId: _uuid.v4(),
      grantId: grantId,
      sessionId: grant.sessionId,
      recipientWallet: grant.recipientWallet,
      accessedAt: now,
      accessType: 'access_revoked',
      verifiedOnchain: false,
      notes: 'Access revoked by owner',
    ));

    return txSig;
  }

  @override
  Future<GrantVerification> verifyGrant({
    required String sessionId,
    required String recipientWallet,
  }) async {
    await _simulateLatency();

    final grant = _grants.values.where(
      (g) => g.sessionId == sessionId &&
          g.recipientWallet == recipientWallet,
    ).lastOrNull;

    if (grant == null) {
      return const GrantVerification(
        manifestHashMatch: false,
        walletSignatureValid: false,
        grantActive: false,
        tokenActive: false,
        aiReportHashMatch: false,
        scopeMatch: false,
        rawDataNotExposed: true,
        errorMessage: 'No grant found for this session and wallet.',
      );
    }

    final token = _tokens[grant.grantId];
    final isActive = grant.isActive;
    final tokenIsActive = token != null && token.status == TokenStatus.active;

    _accessLogs.add(AccessLog(
      accessId: _uuid.v4(),
      grantId: grant.grantId,
      sessionId: sessionId,
      recipientWallet: recipientWallet,
      accessedAt: DateTime.now(),
      accessType: 'verification_check',
      verifiedOnchain: false,
      notes: isActive ? 'Verification passed' : 'Verification failed: ${grant.revoked ? "revoked" : "expired"}',
    ));

    return GrantVerification(
      manifestHashMatch: true,
      walletSignatureValid: true,
      grantActive: isActive,
      tokenActive: tokenIsActive,
      aiReportHashMatch: true,
      scopeMatch: true,
      rawDataNotExposed: true,
      errorMessage: isActive ? null : 'Access ${grant.revoked ? "revoked" : "expired"}.',
    );
  }

  @override
  Future<List<AccessLog>> getAccessHistory({required String sessionId}) async {
    return _accessLogs.where((l) => l.sessionId == sessionId).toList();
  }

  @override
  Future<List<ConsentGrant>> getGrants({required String sessionId}) async {
    return _grants.values.where((g) => g.sessionId == sessionId).toList();
  }

  @override
  Future<DataAccessToken?> getToken({required String grantId}) async {
    return _tokens[grantId];
  }

  void _requireWallet() {
    if (_walletAddress == null) {
      throw StateError('Wallet not connected. Call connectWallet() first.');
    }
  }

  Future<void> _simulateLatency() =>
      Future.delayed(const Duration(milliseconds: 300));

  // Base58 alphabet (Bitcoin / Solana — no `0`, `O`, `I`, `l`).
  static const _base58 =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String _generateMockWallet() =>
      List.generate(44, (_) => _base58[_rng.nextInt(_base58.length)]).join();

  static String _generateMockTxSignature() =>
      List.generate(88, (_) => _base58[_rng.nextInt(_base58.length)]).join();
}

class _SessionCommitment {
  final String ownerWallet;
  final String manifestHash;
  final String rawFileHash;
  final String txSignature;
  final List<String> metadataTags;
  final DateTime createdAt;

  const _SessionCommitment({
    required this.ownerWallet,
    required this.manifestHash,
    required this.rawFileHash,
    required this.txSignature,
    required this.metadataTags,
    required this.createdAt,
  });
}
