import '../../domain/models/solana_models.dart';

/// Abstract interface for Solana consent operations.
///
/// Implementations: [MockSolanaService] (in-memory), DevnetSolanaService
/// (real devnet via memo or Anchor).
abstract class SolanaConsentService {
  SolanaMode get mode;

  Future<String> connectWallet();

  String? get connectedWallet;

  Future<String> commitSession({
    required String manifestHash,
    required String rawFileHash,
    List<String> metadataTags = const [],
  });

  Future<ConsentGrantResult> grantAccess({
    required String sessionId,
    required String manifestHash,
    required String recipientWallet,
    required ConsentScope scope,
    required DateTime expiresAt,
    required ConsentPurpose purpose,
  });

  Future<String> revokeAccess({required String grantId});

  Future<GrantVerification> verifyGrant({
    required String sessionId,
    required String recipientWallet,
  });

  Future<List<AccessLog>> getAccessHistory({required String sessionId});

  Future<List<ConsentGrant>> getGrants({required String sessionId});

  Future<DataAccessToken?> getToken({required String grantId});
}

class ConsentGrantResult {
  final ConsentGrant grant;
  final DataAccessToken token;
  final String txSignature;

  const ConsentGrantResult({
    required this.grant,
    required this.token,
    required this.txSignature,
  });
}
