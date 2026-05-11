import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthlog/data/ai/ai_report_service.dart';
import 'package:healthlog/data/crypto/encryption_service.dart';
import 'package:healthlog/data/crypto/hashing_service.dart';
import 'package:healthlog/data/crypto/verification_service.dart';
import 'package:healthlog/domain/models/solana_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('EncryptionService', () {
    test('encrypts and decrypts a real file without preserving plaintext',
        () async {
      final dir = Directory.systemTemp.createTempSync('healthlog_crypto_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final rawFile = File('${dir.path}/session.csv');
      const plaintext = 'timestamp,eeg_tp9,eeg_af7\n1000,0.5,0.3\n';
      await rawFile.writeAsString(plaintext);

      final service = EncryptionService();
      final result = await service.encryptFile(rawFile);
      final encryptedBytes = await result.encryptedFile.readAsBytes();

      expect(result.encryptedFile.path, '${rawFile.path}.enc');
      expect(encryptedBytes.length, greaterThan(plaintext.length));
      expect(utf8.decode(encryptedBytes, allowMalformed: true),
          isNot(contains(plaintext)));

      final decryptedFile = await service.decryptFile(result.encryptedFile);
      expect(await decryptedFile.readAsString(), plaintext);
    });

    test('tampered ciphertext fails to decrypt', () async {
      final dir = Directory.systemTemp.createTempSync('healthlog_tamper_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final rawFile = File('${dir.path}/session.csv');
      await rawFile.writeAsString('timestamp,eeg\n1000,0.5\n');

      final service = EncryptionService();
      final result = await service.encryptFile(rawFile);
      final bytes = await result.encryptedFile.readAsBytes();
      bytes[bytes.length - 1] ^= 0x01;
      await result.encryptedFile.writeAsBytes(bytes);

      expect(
        () => service.decryptFile(result.encryptedFile),
        throwsA(anything),
      );
    });
  });

  group('HashingService', () {
    test('canonical JSON hash is stable across map insertion order', () {
      final hashing = HashingService();
      final first = {
        'b': 2,
        'a': {
          'z': true,
          'm': [3, 1],
        },
      };
      final second = {
        'a': {
          'm': [3, 1],
          'z': true,
        },
        'b': 2,
      };

      expect(hashing.canonicalJson(first), hashing.canonicalJson(second));
      expect(
        hashing.hashCanonicalJson(first),
        hashing.hashCanonicalJson(second),
      );
    });
  });

  group('AI report verification', () {
    test('fails when summary content is tampered after hashing', () async {
      final hashing = HashingService();
      final aiService = AIReportService(hashingService: hashing);
      final verificationService =
          MockVerificationService(hashingService: hashing);
      final now = DateTime(2026, 5, 11, 12);
      final session = WearableSession(
        id: 'ai-tamper-test',
        sourceDevice: DataSourceType.muselog,
        sourceAdapter: 'muselog',
        signalTypes: const ['EEG', 'IMU'],
        startedAt: now.subtract(const Duration(minutes: 5)),
        endedAt: now,
        createdAt: now,
        sampleCount: 100,
      );

      final report = await aiService.generateSessionSummary(
        session: session,
        manifestHash: 'manifest-hash',
      );
      final tamperedReport = AIReport(
        reportId: report.reportId,
        sessionId: report.sessionId,
        reportType: report.reportType,
        inputManifestHash: report.inputManifestHash,
        permittedDataScope: report.permittedDataScope,
        accessGrantId: report.accessGrantId,
        outputHash: report.outputHash,
        summaryJson: {
          ...report.summaryJson,
          'sampleCount': 999999,
        },
        verifierStatus: report.verifierStatus,
        disclaimer: report.disclaimer,
        createdAt: report.createdAt,
      );

      final original = await verificationService.verifyAIReportChain(
        report: report,
        manifestHash: 'manifest-hash',
      );
      final tampered = await verificationService.verifyAIReportChain(
        report: tamperedReport,
        manifestHash: 'manifest-hash',
      );

      expect(original.isValid, isTrue);
      expect(tampered.isValid, isFalse);
    });
  });
}
