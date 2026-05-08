import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:healthlog/domain/models/solana_models.dart';
import 'package:healthlog/data/solana/mock_solana_service.dart';
import 'package:healthlog/data/ai/ai_report_service.dart';
import 'package:healthlog/data/crypto/hashing_service.dart';

void main() {
  late MockSolanaService solana;
  late AIReportService aiService;
  late HashingService hashingService;

  setUp(() {
    solana = MockSolanaService();
    hashingService = HashingService();
    aiService = AIReportService(hashingService: hashingService);
  });

  group('AES encryption', () {
    test('Encrypt then decrypt round trip produces original bytes', () {
      const keyLength = 32;
      const ivLength = 12;

      final key = enc.Key.fromSecureRandom(keyLength);
      final iv = enc.IV.fromSecureRandom(ivLength);

      const plaintext = 'timestamp,eeg_tp9,eeg_af7\n1000,0.5,0.3\n2000,0.6,0.4';
      final plainBytes = utf8.encode(plaintext);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

      final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
      combined.setAll(0, iv.bytes);
      combined.setAll(iv.bytes.length, encrypted.bytes);

      final recoveredIv = enc.IV(Uint8List.fromList(combined.sublist(0, ivLength)));
      final cipherBytes = combined.sublist(ivLength);
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(cipherBytes)),
        iv: recoveredIv,
      );

      expect(decrypted, equals(plainBytes));
      expect(utf8.decode(decrypted), equals(plaintext));
    });
  });

  group('Hashing determinism', () {
    test('Same file bytes produce same rawFileHash', () async {
      final tmpDir = Directory.systemTemp.createTempSync('healthlog_test_');
      final file = File('${tmpDir.path}/test.csv')
        ..writeAsStringSync('timestamp,eeg_tp9,eeg_af7\n1000,0.5,0.3\n');

      final hash1 = await hashingService.hashRawFile(file);
      final hash2 = await hashingService.hashRawFile(file);

      expect(hash1, equals(hash2));
      expect(hash1, isNotEmpty);

      tmpDir.deleteSync(recursive: true);
    });

    test('Same manifest fields produce same manifestHash', () {
      final now = DateTime(2025, 1, 15, 10, 30);
      final session = WearableSession(
        id: 'deterministic-test',
        sourceDevice: DataSourceType.muselog,
        sourceAdapter: 'muselog',
        signalTypes: const ['EEG', 'IMU'],
        rawFileHash: 'abc123',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 5)),
        createdAt: now,
      );

      final manifest1 = hashingService.createSessionManifest(session);
      final hash1 = hashingService.hashManifest(manifest1);

      final manifest2 = hashingService.createSessionManifest(session);
      final hash2 = hashingService.hashManifest(manifest2);

      expect(hash1, equals(hash2));
      expect(hash1, isNotEmpty);
    });
  });

  group('Commit payload safety', () {
    test('Commit payload contains no raw health data', () async {
      await solana.connectWallet();
      final txSig = await solana.commitSession(
        manifestHash: 'safe-hash-001',
        rawFileHash: 'safe-hash-002',
        metadataTags: ['EEG', 'IMU'],
      );

      expect(txSig, isNotEmpty);
      expect(txSig.contains('0.5'), isFalse);
      expect(txSig.contains('csv'), isFalse);
    });

    test('Devnet memo payload contains only privacy-safe fields', () {
      final payload = jsonEncode({
        'type': 'session_commitment',
        'owner': 'TestWallet123',
        'manifestHash': 'abc123',
        'rawFileHash': 'def456',
        'tags': ['EEG', 'IMU'],
        'ts': DateTime.now().toIso8601String(),
      });

      expect(payload.contains('session_commitment'), isTrue);
      expect(payload.contains('manifestHash'), isTrue);
      expect(payload.contains('rawFileHash'), isTrue);

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final allowedKeys = {
        'type', 'owner', 'manifestHash', 'rawFileHash', 'tags', 'ts'
      };
      for (final key in decoded.keys) {
        expect(allowedKeys.contains(key), isTrue,
            reason: 'Unexpected key "$key" in devnet payload');
      }
    });
  });

  group('Grant / Revoke lifecycle', () {
    test('Grant then verify passes', () async {
      await solana.connectWallet();

      await solana.grantAccess(
        sessionId: 'lifecycle-session',
        manifestHash: 'lifecycle-hash',
        recipientWallet: 'Recipient001',
        scope: ConsentScope.aiSummaryOnly,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        purpose: ConsentPurpose.aiAnalysis,
      );

      final verification = await solana.verifyGrant(
        sessionId: 'lifecycle-session',
        recipientWallet: 'Recipient001',
      );

      expect(verification.grantActive, isTrue);
      expect(verification.tokenActive, isTrue);
      expect(verification.allPassed, isTrue);
    });

    test('Revoke then verify fails', () async {
      await solana.connectWallet();

      final result = await solana.grantAccess(
        sessionId: 'revoke-session',
        manifestHash: 'revoke-hash',
        recipientWallet: 'Recipient002',
        scope: ConsentScope.aiSummaryOnly,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        purpose: ConsentPurpose.aiAnalysis,
      );

      await solana.revokeAccess(grantId: result.grant.grantId);

      final verification = await solana.verifyGrant(
        sessionId: 'revoke-session',
        recipientWallet: 'Recipient002',
      );

      expect(verification.grantActive, isFalse);
      expect(verification.tokenActive, isFalse);
      expect(verification.allPassed, isFalse);
    });
  });

  group('AI report scope', () {
    test('AI report contains permittedDataScope', () async {
      final session = WearableSession(
        id: 'ai-scope-test',
        sourceDevice: DataSourceType.muselog,
        sourceAdapter: 'muselog',
        signalTypes: const ['EEG', 'IMU'],
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        endedAt: DateTime.now(),
        createdAt: DateTime.now(),
        sampleCount: 500,
        deviceName: 'Muse-2',
        manifestHash: 'manifest-for-ai',
      );

      final report = await aiService.generateSessionSummary(
        session: session,
        manifestHash: 'manifest-for-ai',
        scope: ConsentScope.derivedFeaturesOnly,
      );

      expect(report.permittedDataScope, ConsentScope.derivedFeaturesOnly);
      expect(report.inputManifestHash, 'manifest-for-ai');
      expect(report.verifierStatus, isTrue);
    });

    test('AI report does not include raw file paths or raw signal values',
        () async {
      final session = WearableSession(
        id: 'ai-safety-test',
        sourceDevice: DataSourceType.muselog,
        sourceAdapter: 'muselog',
        signalTypes: const ['EEG', 'IMU'],
        rawFileUri: '/secret/path/eeg_data.csv',
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        endedAt: DateTime.now(),
        createdAt: DateTime.now(),
        sampleCount: 300,
        deviceName: 'Muse-S',
        manifestHash: 'manifest-safe',
      );

      final report = await aiService.generateSessionSummary(
        session: session,
        manifestHash: 'manifest-safe',
      );

      final summaryStr = jsonEncode(report.summaryJson);
      expect(summaryStr.contains('/secret/path'), isFalse,
          reason: 'AI report must not contain raw file paths');
      expect(summaryStr.contains('eeg_data.csv'), isFalse,
          reason: 'AI report must not contain raw file names');
    });
  });

  group('DataAccessToken', () {
    test('DataAccessToken becomes revoked after revoke', () async {
      await solana.connectWallet();

      final result = await solana.grantAccess(
        sessionId: 'token-revoke-test',
        manifestHash: 'token-hash',
        recipientWallet: 'TokenRecipient',
        scope: ConsentScope.aiSummaryOnly,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        purpose: ConsentPurpose.personalHealth,
      );

      final tokenBefore = await solana.getToken(
          grantId: result.grant.grantId);
      expect(tokenBefore, isNotNull);
      expect(tokenBefore!.status, TokenStatus.active);

      await solana.revokeAccess(grantId: result.grant.grantId);

      final tokenAfter = await solana.getToken(
          grantId: result.grant.grantId);
      expect(tokenAfter, isNotNull);
      expect(tokenAfter!.status, TokenStatus.revoked);
    });
  });
}
