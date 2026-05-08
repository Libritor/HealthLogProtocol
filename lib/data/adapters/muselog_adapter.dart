import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../domain/models/solana_models.dart';
import 'wearable_adapter.dart';

class MuseLogAdapter implements WearableAdapter {
  static const _uuid = Uuid();

  @override
  String get id => 'muselog';

  @override
  String get name => 'MuseLog';

  @override
  List<String> get supportedSignalTypes =>
      const ['EEG', 'BandPower', 'IMU', 'fNIRS', 'PPG', 'HSI'];

  @override
  Future<WearableSession> importSession(File file) async {
    final header = await _readHeader(file);
    final detectedSignals = _detectSignalTypes(header);
    final stats = await _gatherStats(file);

    final fileName = file.uri.pathSegments.last;
    final deviceName = _extractDeviceName(fileName);

    return WearableSession(
      id: _uuid.v4(),
      sourceDevice: DataSourceType.muselog,
      sourceAdapter: id,
      signalTypes: detectedSignals,
      rawFileUri: file.path,
      startedAt: stats.firstTimestamp ?? DateTime.now(),
      endedAt: stats.lastTimestamp,
      createdAt: DateTime.now(),
      sampleCount: stats.rowCount,
      deviceName: deviceName,
      sessionName: fileName.replaceAll('.csv', ''),
    );
  }

  Future<List<String>> _readHeader(File file) async {
    final lines = await file.openRead()
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .take(1)
        .toList();
    if (lines.isEmpty) return [];
    return lines.first.split(',').map((c) => c.trim()).toList();
  }

  List<String> _detectSignalTypes(List<String> headers) {
    final signals = <String>{};
    final headerSet = headers.toSet();

    final eegCols = AppConstants.columnGroups['EEG Raw'] ?? [];
    if (eegCols.any(headerSet.contains)) signals.add('EEG');

    final absCols = AppConstants.columnGroups['Band Powers (Absolute)'] ?? [];
    if (absCols.any(headerSet.contains)) signals.add('BandPower');

    final imuCols = AppConstants.columnGroups['IMU'] ?? [];
    if (imuCols.any(headerSet.contains)) signals.add('IMU');

    final fnirsCols = AppConstants.columnGroups['fNIRS'] ?? [];
    if (fnirsCols.any(headerSet.contains)) signals.add('fNIRS');

    final hsiCols = AppConstants.columnGroups['HSI & Quality'] ?? [];
    if (hsiCols.any(headerSet.contains)) signals.add('HSI');

    return signals.toList()..sort();
  }

  Future<_CsvStats> _gatherStats(File file) async {
    int rowCount = 0;
    DateTime? first;
    DateTime? last;

    final lines = await file.openRead()
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .toList();

    if (lines.length < 2) return _CsvStats(0, null, null);

    final header = lines.first.split(',').map((c) => c.trim()).toList();
    final clockIdx = header.indexOf('CLOCK_TIME');

    for (var i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length <= 1) continue;
      rowCount++;
      if (clockIdx >= 0 && clockIdx < cols.length) {
        final ts = DateTime.tryParse(cols[clockIdx].trim());
        if (ts != null) {
          first ??= ts;
          last = ts;
        }
      }
    }

    return _CsvStats(rowCount, first, last);
  }

  String? _extractDeviceName(String fileName) {
    final match = RegExp(r'muse_session_\d{8}_\d{6}_(.+)\.csv')
        .firstMatch(fileName);
    return match?.group(1)?.replaceAll('_', ' ');
  }
}

class _CsvStats {
  final int rowCount;
  final DateTime? firstTimestamp;
  final DateTime? lastTimestamp;
  const _CsvStats(this.rowCount, this.firstTimestamp, this.lastTimestamp);
}
