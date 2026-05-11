import '../../domain/models/solana_models.dart';
import 'hashing_service.dart';

/// ZK-ready verification interface.
///
/// MVP: mock proofs using hashes and signatures.
/// UI should say "ZK-ready verification interface", never "ZK proof generated."
///
// TODO: Replace mock proofs with ZK compression, Merkle proofs, or
// privacy-preserving claim verification when real ZK tooling is integrated.

abstract class VerificationService {
  Future<VerificationResult> verifySessionOwnership({
    required String sessionId,
    required String ownerWallet,
    required String manifestHash,
  });

  Future<VerificationResult> verifyConsentScope({
    required ConsentGrant grant,
    required ConsentScope requestedScope,
  });

  Future<VerificationResult> verifyAIReportChain({
    required AIReport report,
    required String manifestHash,
  });

  Future<VerificationResult> verifyNegativeScope({
    required ConsentGrant grant,
    required ConsentScope deniedScope,
  });

  Future<VerificationResult> verifySessionAfterDate({
    required WearableSession session,
    required DateTime afterDate,
  });
}

class MockVerificationService implements VerificationService {
  final HashingService _hashingService;

  MockVerificationService({HashingService? hashingService})
      : _hashingService = hashingService ?? HashingService();

  @override
  Future<VerificationResult> verifySessionOwnership({
    required String sessionId,
    required String ownerWallet,
    required String manifestHash,
  }) async {
    final proofData = _hashingService.hashString(
      '$sessionId:$ownerWallet:$manifestHash',
    );
    return VerificationResult(
      claimType: 'session_ownership',
      claimDescription: 'This user has an authorized MuseLog session',
      isValid: manifestHash.isNotEmpty && ownerWallet.isNotEmpty,
      proofData: proofData,
      proofType: 'mock_hash',
    );
  }

  @override
  Future<VerificationResult> verifyConsentScope({
    required ConsentGrant grant,
    required ConsentScope requestedScope,
  }) async {
    final scopeMatch = grant.scope == requestedScope;
    final isActive = grant.isActive;
    return VerificationResult(
      claimType: 'consent_scope',
      claimDescription:
          'This recipient has active consent to access ${requestedScope.displayName}',
      isValid: scopeMatch && isActive,
      proofData: _hashingService.hashString(
        '${grant.grantId}:${grant.scope.name}:${grant.isActive}',
      ),
      proofType: 'mock_hash',
    );
  }

  @override
  Future<VerificationResult> verifyAIReportChain({
    required AIReport report,
    required String manifestHash,
  }) async {
    final hashMatch = report.inputManifestHash == manifestHash;
    final expectedOutputHash =
        _hashingService.hashCanonicalJson(report.summaryJson);
    final outputHashMatch = report.outputHash == expectedOutputHash;
    return VerificationResult(
      claimType: 'ai_report_chain',
      claimDescription:
          'This AI summary was generated from a committed wearable session',
      isValid: hashMatch && outputHashMatch && report.verifierStatus,
      proofData: _hashingService.hashString(
        '${report.reportId}:${report.inputManifestHash}:'
        '${report.outputHash}:$expectedOutputHash',
      ),
      proofType: 'mock_hash',
    );
  }

  @override
  Future<VerificationResult> verifyNegativeScope({
    required ConsentGrant grant,
    required ConsentScope deniedScope,
  }) async {
    final notGranted = grant.scope != deniedScope;
    return VerificationResult(
      claimType: 'negative_scope',
      claimDescription:
          'This recipient does not have permission to access ${deniedScope.displayName}',
      isValid: notGranted,
      proofData: _hashingService.hashString(
        '${grant.grantId}:denied:${deniedScope.name}',
      ),
      proofType: 'mock_hash',
    );
  }

  @override
  Future<VerificationResult> verifySessionAfterDate({
    required WearableSession session,
    required DateTime afterDate,
  }) async {
    final isAfter = session.startedAt.isAfter(afterDate);
    return VerificationResult(
      claimType: 'session_after_date',
      claimDescription:
          'This session was recorded after ${afterDate.toIso8601String().substring(0, 10)}',
      isValid: isAfter,
      proofData: _hashingService.hashString(
        '${session.id}:after:${afterDate.toIso8601String()}',
      ),
      proofType: 'mock_hash',
    );
  }
}

class VerificationResult {
  final String claimType;
  final String claimDescription;
  final bool isValid;
  final String proofData;
  final String proofType;

  const VerificationResult({
    required this.claimType,
    required this.claimDescription,
    required this.isValid,
    required this.proofData,
    required this.proofType,
  });
}
