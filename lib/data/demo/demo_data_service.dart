import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/solana_models.dart';
import '../crypto/hashing_service.dart';

/// Generates synthetic MuseLog demo data so the full golden-path demo
/// can run from a fresh clone without a real Muse device, SDK, or
/// private API keys.
class DemoDataService {
  final HashingService _hashingService;

  DemoDataService({HashingService? hashingService})
      : _hashingService = hashingService ?? HashingService();

  Future<DemoBundle> loadDemoData({String? ownerWallet}) async {
    final csvFile = await _writeSyntheticCsv();
    final rawFileHash = await _hashingService.hashRawFile(csvFile);
    final now = DateTime.now();

    final session = WearableSession(
      id: 'demo-muselog-001',
      ownerWallet: ownerWallet ??
          'DemoWallet1111111111111111111111111111111111',
      sourceDevice: DataSourceType.muselog,
      sourceAdapter: 'muselog',
      signalTypes: const ['EEG', 'BandPower', 'IMU', 'HSI'],
      rawFileUri: csvFile.path,
      rawFileHash: rawFileHash,
      encryptionStatus: SessionEncryptionStatus.unencrypted,
      onchainStatus: OnchainStatus.private_,
      aiSummaryStatus: AISummaryStatus.none,
      startedAt: now.subtract(const Duration(minutes: 5)),
      endedAt: now,
      createdAt: now,
      sampleCount: 76800,
      deviceName: 'Muse-2 Demo',
      sessionName: 'Demo MuseLog Session (EEG + IMU)',
    );

    final manifest = _hashingService.createSessionManifest(session);
    final manifestHash = _hashingService.hashManifest(manifest);

    final updatedSession = session.copyWith(manifestHash: manifestHash);

    return DemoBundle(
      session: updatedSession,
      manifest: manifest,
      manifestHash: manifestHash,
      csvFile: csvFile,
    );
  }

  Future<File> _writeSyntheticCsv() async {
    final dir = await getApplicationDocumentsDirectory();
    final demoDir = Directory('${dir.path}/muse_sessions');
    if (!await demoDir.exists()) {
      await demoDir.create(recursive: true);
    }

    final file = File('${demoDir.path}/demo_muselog_session.csv');
    if (await file.exists()) return file;

    final rng = Random(42);
    const sampleRate = 256;
    const durationSeconds = 300;
    final buf = StringBuffer();

    buf.writeln(
      'PACKET_TYPE,DEVICE_NAME,CLOCK_TIME,ms_ELAPSED,TRIGGER_COUNT,'
      'TP9_CONNECTION_STRENGTH(HSI),TP9_ARTIFACT_FREE(IS_GOOD),'
      'AF7_CONNECTION_STRENGTH(HSI),AF7_ARTIFACT_FREE(IS_GOOD),'
      'AF8_CONNECTION_STRENGTH(HSI),AF8_ARTIFACT_FREE(IS_GOOD),'
      'TP10_CONNECTION_STRENGTH(HSI),TP10_ARTIFACT_FREE(IS_GOOD),'
      'TP9_RAW,AF7_RAW,AF8_RAW,TP10_RAW,DRL,REF,'
      'TP9_DELTA_ABSOLUTE,AF7_DELTA_ABSOLUTE,AF8_DELTA_ABSOLUTE,TP10_DELTA_ABSOLUTE,'
      'TP9_THETA_ABSOLUTE,AF7_THETA_ABSOLUTE,AF8_THETA_ABSOLUTE,TP10_THETA_ABSOLUTE,'
      'TP9_ALPHA_ABSOLUTE,AF7_ALPHA_ABSOLUTE,AF8_ALPHA_ABSOLUTE,TP10_ALPHA_ABSOLUTE,'
      'TP9_BETA_ABSOLUTE,AF7_BETA_ABSOLUTE,AF8_BETA_ABSOLUTE,TP10_BETA_ABSOLUTE,'
      'TP9_GAMMA_ABSOLUTE,AF7_GAMMA_ABSOLUTE,AF8_GAMMA_ABSOLUTE,TP10_GAMMA_ABSOLUTE,'
      'GYRO_X,GYRO_Y,GYRO_Z,ACCEL_X,ACCEL_Y,ACCEL_Z',
    );

    final baseTime = DateTime.now().subtract(const Duration(minutes: 5));
    final totalSamples = sampleRate * durationSeconds;

    for (var i = 0; i < totalSamples; i++) {
      final t = baseTime.add(Duration(milliseconds: (i * 1000 ~/ sampleRate)));
      final ms = (i * 1000 / sampleRate).toStringAsFixed(1);

      final eeg = List.generate(4, (_) => (rng.nextDouble() * 200 - 100).toStringAsFixed(2));
      final drl = (rng.nextDouble() * 10).toStringAsFixed(2);
      final ref = (rng.nextDouble() * 10).toStringAsFixed(2);

      final bandPower = List.generate(20, (_) => (rng.nextDouble() * 2).toStringAsFixed(4));

      final gyro = List.generate(3, (_) => (rng.nextDouble() * 10 - 5).toStringAsFixed(3));
      final accel = List.generate(3, (j) {
        final base = j == 2 ? 9.8 : 0.0;
        return (base + rng.nextDouble() * 0.5 - 0.25).toStringAsFixed(3);
      });

      buf.writeln(
        'EEG,Muse-2 Demo,${t.toIso8601String()},$ms,0,'
        '1,1,1,1,1,1,1,1,'
        '${eeg.join(',')},$drl,$ref,'
        '${bandPower.join(',')},'
        '${gyro.join(',')},${accel.join(',')}',
      );
    }

    await file.writeAsString(buf.toString());
    return file;
  }
}

class DemoBundle {
  final WearableSession session;
  final SessionManifest manifest;
  final String manifestHash;
  final File csvFile;

  const DemoBundle({
    required this.session,
    required this.manifest,
    required this.manifestHash,
    required this.csvFile,
  });
}
