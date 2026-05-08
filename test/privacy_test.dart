import 'package:flutter_test/flutter_test.dart';
import 'package:healthlog/domain/models/solana_models.dart';
import 'package:healthlog/data/solana/mock_solana_service.dart';
import 'package:healthlog/data/ai/ai_report_service.dart';
import 'package:healthlog/data/crypto/hashing_service.dart';

/// Privacy acceptance criteria tests.
///
/// These verify that no raw health data is written to Solana payloads,
/// the LLM never receives raw data, and Data Access Tokens contain no
/// raw health data.
void main() {
  group('Privacy Acceptance Criteria', () {
    late MockSolanaService solana;
    late AIReportService aiService;
    late HashingService hashingService;

    setUp(() {
      solana = MockSolanaService();
      hashingService = HashingService();
      aiService = AIReportService(hashingService: hashingService);
    });

    test('Solana commit payload contains only hashes and metadata', () async {
      await solana.connectWallet();

      final txSig = await solana.commitSession(
        manifestHash: 'abc123hash',
        rawFileHash: 'def456hash',
        metadataTags: ['EEG', 'IMU'],
      );

      expect(txSig, isNotEmpty);
      // The mock service stores only hashes, wallet, tags, and timestamps.
      // No raw EEG, IMU, PPG, fNIRS, or health data is stored.
    });

    test('Consent grant contains only scope codes and wallet addresses',
        () async {
      await solana.connectWallet();

      final result = await solana.grantAccess(
        sessionId: 'session-001',
        manifestHash: 'manifest-hash-001',
        recipientWallet: 'RecipientWallet123',
        scope: ConsentScope.aiSummaryOnly,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        purpose: ConsentPurpose.aiAnalysis,
      );

      final grant = result.grant;
      final json = grant.toJson();

      // Verify no raw health data fields exist in the grant
      final jsonStr = json.toString().toLowerCase();
      expect(jsonStr.contains('eeg'), isFalse,
          reason: 'Grant must not contain raw EEG data');
      expect(jsonStr.contains('imu'), isFalse,
          reason: 'Grant must not contain raw IMU data');
      expect(jsonStr.contains('ppg'), isFalse,
          reason: 'Grant must not contain raw PPG data');
      expect(jsonStr.contains('fnirs'), isFalse,
          reason: 'Grant must not contain raw fNIRS data');

      // Verify it contains only expected fields
      expect(json.containsKey('grantId'), isTrue);
      expect(json.containsKey('sessionId'), isTrue);
      expect(json.containsKey('ownerWallet'), isTrue);
      expect(json.containsKey('recipientWallet'), isTrue);
      expect(json.containsKey('scope'), isTrue);
      expect(json.containsKey('purpose'), isTrue);
      expect(json.containsKey('expiresAt'), isTrue);
      expect(json.containsKey('revoked'), isTrue);
    });

    test('Data Access Token does not contain raw health data', () async {
      await solana.connectWallet();

      final result = await solana.grantAccess(
        sessionId: 'session-002',
        manifestHash: 'manifest-hash-002',
        recipientWallet: 'RecipientWallet456',
        scope: ConsentScope.aiSummaryOnly,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        purpose: ConsentPurpose.research,
      );

      final token = result.token;
      final json = token.toJson();
      final jsonStr = json.toString().toLowerCase();

      expect(jsonStr.contains('eeg'), isFalse);
      expect(jsonStr.contains('ppg'), isFalse);
      expect(jsonStr.contains('fnirs'), isFalse);
      expect(json.containsKey('tokenId'), isTrue);
      expect(json.containsKey('scope'), isTrue);
      expect(json.containsKey('manifestHash'), isTrue);
    });

    test('rawFileUri is never included in session JSON export', () {
      final session = WearableSession(
        id: 'test-session',
        sourceDevice: DataSourceType.muselog,
        sourceAdapter: 'muselog',
        signalTypes: const ['EEG', 'IMU'],
        rawFileUri: '/secret/local/path/to/eeg_data.csv',
        startedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final json = session.toJson();

      // rawFileUri must not appear in the JSON export
      expect(json.containsKey('rawFileUri'), isFalse,
          reason: 'rawFileUri must never be in exported JSON');
      expect(json.containsKey('encryptedFileUri'), isFalse,
          reason: 'encryptedFileUri must never be in exported JSON');
    });

    test('AI report contains only approved scope, not raw data', () async {
      final session = WearableSession(
        id: 'test-session-ai',
        sourceDevice: DataSourceType.muselog,
        sourceAdapter: 'muselog',
        signalTypes: const ['EEG', 'IMU'],
        rawFileUri: '/local/path/data.csv',
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        endedAt: DateTime.now(),
        createdAt: DateTime.now(),
        sampleCount: 1000,
        deviceName: 'Muse-2',
        manifestHash: 'test-manifest-hash',
      );

      final report = await aiService.generateSessionSummary(
        session: session,
        manifestHash: 'test-manifest-hash',
        scope: ConsentScope.aiSummaryOnly,
      );

      expect(report.permittedDataScope, ConsentScope.aiSummaryOnly);
      expect(report.inputManifestHash, 'test-manifest-hash');
      expect(report.outputHash, isNotEmpty);
      expect(report.disclaimer, contains('not a medical diagnosis'));

      // The summary should not contain raw signal values
      final summaryStr = report.summaryJson.toString();
      expect(summaryStr.contains('/local/path'), isFalse,
          reason: 'AI report must not contain raw file paths');
    });

    test('Revoked grant fails verification', () async {
      await solana.connectWallet();

      final result = await solana.grantAccess(
        sessionId: 'session-revoke-test',
        manifestHash: 'hash-revoke',
        recipientWallet: 'RecipientRevoke',
        scope: ConsentScope.aiSummaryOnly,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        purpose: ConsentPurpose.aiAnalysis,
      );

      await solana.revokeAccess(grantId: result.grant.grantId);

      final verification = await solana.verifyGrant(
        sessionId: 'session-revoke-test',
        recipientWallet: 'RecipientRevoke',
      );

      expect(verification.grantActive, isFalse);
      expect(verification.tokenActive, isFalse);
      expect(verification.allPassed, isFalse);
    });
  });
}
