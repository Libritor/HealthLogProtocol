import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/band_power_sample.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../domain/models/imu_sample.dart';
import '../../domain/models/muse_device.dart';

// Writes sensor data to CSV incrementally (no buffering entire session).
// Flushes to disk every _flushInterval rows so data survives app crashes.
class CsvWriter {
  final File file;
  final List<String> selectedColumns;
  final IOSink _sink;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  static const int _flushInterval = 256;

  DateTime? _sessionStartTime;
  int _triggerCount = 0;
  int _rowsSinceFlush = 0;
  bool _headerWritten = false;

  CsvWriter._(this.file, this.selectedColumns, this._sink);

  static Future<CsvWriter> create(File file, List<String> selectedColumns) async {
    await file.parent.create(recursive: true);
    final sink = file.openWrite(mode: FileMode.write);
    return CsvWriter._(file, selectedColumns, sink);
  }

  Future<void> writeHeader() async {
    if (_headerWritten) return;

    final csvConverter = const ListToCsvConverter();
    final headerRow = csvConverter.convert([selectedColumns]);
    _sink.write(headerRow + '\r\n');
    _headerWritten = true;
  }

  // Merges whatever sensor data is available and writes one row.
  Future<void> writeRow({
    required String packetType,
    required String deviceName,
    required DateTime timestamp,
    required MuseDevice device,
    EegSample? eegSample,
    BandPowerSample? bandPowerSample,
    FnirsSample? fnirsSample,
    ImuSample? imuSample,
  }) async {
    if (!_headerWritten) {
      await writeHeader();
    }

    _sessionStartTime ??= timestamp;

    final allValues = <String, String>{
      'PACKET_TYPE': packetType,
      'DEVICE_NAME': deviceName,
      'CLOCK_TIME': _dateFormat.format(timestamp),  // Local time (no UTC conversion)
      'ms_ELAPSED':
          timestamp.difference(_sessionStartTime!).inMilliseconds.toString(),
      'TRIGGER_COUNT': _triggerCount.toString(),
      // HSI quality
      'TP9_CONNECTION_STRENGTH(HSI)': device.tp9Hsi.value.toString(),
      'TP9_ARTIFACT_FREE(IS_GOOD)': device.tp9Hsi.isArtifactFree ? '1' : '0',
      'AF7_CONNECTION_STRENGTH(HSI)': device.af7Hsi.value.toString(),
      'AF7_ARTIFACT_FREE(IS_GOOD)': device.af7Hsi.isArtifactFree ? '1' : '0',
      'AF8_CONNECTION_STRENGTH(HSI)': device.af8Hsi.value.toString(),
      'AF8_ARTIFACT_FREE(IS_GOOD)': device.af8Hsi.isArtifactFree ? '1' : '0',
      'TP10_CONNECTION_STRENGTH(HSI)': device.tp10Hsi.value.toString(),
      'TP10_ARTIFACT_FREE(IS_GOOD)': device.tp10Hsi.isArtifactFree ? '1' : '0',
      'BATTERY_PERCENT': device.batteryPercent.toString(),
    };

    if (eegSample != null) {
      allValues.addAll(eegSample.toCsvValues());
    }
    if (bandPowerSample != null) {
      allValues.addAll(bandPowerSample.toCsvValues());
    }
    if (fnirsSample != null) {
      allValues.addAll(fnirsSample.toCsvValues());
    }
    if (imuSample != null) {
      allValues.addAll(imuSample.toCsvValues());
    }

    final row = selectedColumns.map((col) => allValues[col] ?? '').toList();

    final csvConverter = const ListToCsvConverter();
    final csvRow = csvConverter.convert([row]);
    _sink.write(csvRow + '\r\n');

    _rowsSinceFlush++;
    if (_rowsSinceFlush >= _flushInterval) {
      _rowsSinceFlush = 0;
      _sink.flush();
    }
  }

  void incrementTrigger() {
    _triggerCount++;
  }

  void setTriggerCount(int count) {
    _triggerCount = count;
  }

  int get triggerCount => _triggerCount;

  Future<void> flush() async {
    await _sink.flush();
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
