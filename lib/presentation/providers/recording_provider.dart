import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/band_power_sample.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../domain/models/imu_sample.dart';
import '../../data/storage/csv_writer.dart';
import '../../data/storage/file_storage_helper.dart';
import '../../core/constants.dart';
import '../../data/camera/camera_recording_service.dart';
import 'device_provider.dart';
import 'camera_provider.dart';

final sessionConfigProvider =
    StateNotifierProvider<SessionConfigNotifier, SessionConfig?>((ref) {
  return SessionConfigNotifier();
});

class SessionConfigNotifier extends StateNotifier<SessionConfig?> {
  SessionConfigNotifier() : super(null);

  void createConfig({
    required List<String> selectedDeviceIds,
    required Set<String> selectedColumns,
    required String sessionName,
    String notes = '',
    bool recordVideo = false,
    bool includeOura = false,
    bool includeRayBan = false,
    List<String> raybanMediaPaths = const [],
  }) {
    state = SessionConfig(
      selectedDeviceIds: selectedDeviceIds,
      selectedColumns: selectedColumns,
      sessionName: sessionName,
      notes: notes,
      startTime: DateTime.now(),
      recordVideo: recordVideo,
      includeOura: includeOura,
      includeRayBan: includeRayBan,
      raybanMediaPaths: raybanMediaPaths,
    );
  }

  void clearConfig() {
    state = null;
  }
}

final recordingStateProvider =
    StateNotifierProvider<RecordingStateNotifier, RecordingState>((ref) {
  return RecordingStateNotifier();
});

class RecordingStateNotifier extends StateNotifier<RecordingState> {
  RecordingStateNotifier() : super(RecordingState.idle);

  void startRecording() => state = RecordingState.recording;
  void pauseRecording() => state = RecordingState.paused;
  void resumeRecording() => state = RecordingState.recording;
  void stopRecording() => state = RecordingState.stopped;
  void reset() => state = RecordingState.idle;
}

// Column selection for CSV export
final selectedColumnsProvider =
    StateNotifierProvider<SelectedColumnsNotifier, Set<String>>((ref) {
  return SelectedColumnsNotifier();
});

class SelectedColumnsNotifier extends StateNotifier<Set<String>> {
  SelectedColumnsNotifier() : super(Set.from(AppConstants.csvColumns));

  void toggleColumn(String column) {
    if (state.contains(column)) {
      state = Set.from(state)..remove(column);
    } else {
      state = Set.from(state)..add(column);
    }
  }

  void toggleGroup(String groupName, bool selected) {
    final groupColumns = AppConstants.columnGroups[groupName] ?? [];
    if (selected) {
      state = Set.from(state)..addAll(groupColumns);
    } else {
      state = Set.from(state)..removeAll(groupColumns);
    }
  }

  void selectAll() {
    state = Set.from(AppConstants.csvColumns);
  }

  void clearAll() {
    state = {};
  }
}

// One CSV writer per device
final csvWritersProvider =
    StateNotifierProvider<CsvWritersNotifier, Map<String, CsvWriter>>((ref) {
  return CsvWritersNotifier();
});

class CsvWritersNotifier extends StateNotifier<Map<String, CsvWriter>> {
  CsvWritersNotifier() : super({});

  Future<void> createWriter(String deviceId, String deviceName, List<String> selectedColumns,
      {DateTime? sessionStartTime}) async {
    final file = await FileStorageHelper.generateCsvFilePath(
      deviceId,
      deviceName: deviceName,
      sessionStartTime: sessionStartTime,
    );
    final writer = await CsvWriter.create(file, selectedColumns);
    await writer.writeHeader();
    state = {...state, deviceId: writer};
  }

  CsvWriter? getWriter(String deviceId) => state[deviceId];

  Future<void> closeAll() async {
    for (var writer in state.values) {
      await writer.close();
    }
    state = {};
  }

  Future<void> closeWriter(String deviceId) async {
    final writer = state[deviceId];
    if (writer != null) {
      await writer.close();
      final newState = Map<String, CsvWriter>.from(state);
      newState.remove(deviceId);
      state = newState;
    }
  }
}

final recordingManagerProvider = Provider<RecordingManager>((ref) {
  return RecordingManager(ref);
});

// Coordinates recording across all connected devices.
class RecordingManager {
  final Ref ref;
  final Map<String, StreamSubscription> _subscriptions = {};
  Timer? _recordingTimer;
  DateTime? _sessionStartTime;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  File? _videoFile;

  // Buffer latest data from slower streams to merge with EEG
  final Map<String, BandPowerSample> _latestBandPower = {};
  final Map<String, FnirsSample> _latestFnirs = {};
  final Map<String, ImuSample> _latestImu = {};

  RecordingManager(this.ref);

  File? get videoFile => _videoFile;

  void setVideoFile(File file) {
    _videoFile = file;
  }

  Future<void> startRecording() async {
    final config = ref.read(sessionConfigProvider);
    if (config == null) {
      throw Exception('Session config not set');
    }

    _sessionStartTime = DateTime.now();
    _elapsedSeconds = 0;
    _isPaused = false;
    _videoFile = null;

    _latestBandPower.clear();
    _latestFnirs.clear();
    _latestImu.clear();

    if (config.hasMuseDevices) {
      final csvWritersNotifier = ref.read(csvWritersProvider.notifier);
      final deviceNamesNotifier = ref.read(deviceNamesProvider.notifier);

      for (var deviceId in config.selectedDeviceIds) {
        final deviceName = deviceNamesNotifier.assignName(deviceId);

        await csvWritersNotifier.createWriter(
          deviceId,
          deviceName,
          config.selectedColumns.toList(),
          sessionStartTime: _sessionStartTime,
        );
        await Future.delayed(Duration.zero);
      }

      if (config.recordVideo) {
        final cameraService = ref.read(cameraRecordingServiceProvider);
        final cameraDirection = ref.read(selectedCameraDirectionProvider);
        final videoOrientation = ref.read(selectedVideoOrientationProvider);
        await cameraService.initialize(
          direction: cameraDirection,
          landscape: videoOrientation == VideoOrientation.landscape,
        );
        final primaryDeviceId = config.selectedDeviceIds.first;
        final primaryDeviceName =
            ref.read(deviceNamesProvider)[primaryDeviceId] ?? 'Unknown';
        await cameraService.startRecording(
          deviceId: primaryDeviceId,
          deviceName: primaryDeviceName,
          sessionStartTime: _sessionStartTime,
        );
      }

      for (var deviceId in config.selectedDeviceIds) {
        _subscribeToDeviceStreams(deviceId);
        await Future.delayed(Duration.zero);
      }
    }

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _elapsedSeconds++;
      }
    });

    ref.read(recordingStateProvider.notifier).startRecording();
  }

  void _subscribeToDeviceStreams(String deviceId) {
    final csvWriters = ref.read(csvWritersProvider);
    final writer = csvWriters[deviceId];
    if (writer == null) return;

    final connectedDevices = ref.read(connectedDevicesProvider);
    final device = connectedDevices[deviceId];
    if (device == null) return;

    final deviceName = ref.read(deviceNamesProvider)[deviceId] ?? 'Unknown';
    final museService = ref.read(museServiceProvider);

    final eegSub = museService.subscribeToEeg(deviceId).listen(
      (eegSample) {
        if (_isPaused) return;
        writer.writeRow(
          packetType: 'EEG',
          deviceName: deviceName,
          timestamp: eegSample.timestamp,
          device: device,
          eegSample: eegSample,
          bandPowerSample: _latestBandPower[deviceId],
          fnirsSample: _latestFnirs[deviceId],
          imuSample: _latestImu[deviceId],
        );
      },
      onError: (error) => print('EEG stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_eeg'] = eegSub;

    final bandPowerSub = museService.subscribeToBandPowers(deviceId).listen(
      (bandPowerSample) {
        _latestBandPower[deviceId] = bandPowerSample;
      },
      onError: (error) =>
          print('Band power stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_bandpower'] = bandPowerSub;

    final fnirsSub = museService.subscribeToFnirs(deviceId).listen(
      (fnirsSample) {
        _latestFnirs[deviceId] = fnirsSample;
      },
      onError: (error) => print('fNIRS stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_fnirs'] = fnirsSub;

    final imuSub = museService.subscribeToImu(deviceId).listen(
      (imuSample) {
        _latestImu[deviceId] = imuSample;
      },
      onError: (error) => print('IMU stream error for $deviceId: $error'),
    );
    _subscriptions['${deviceId}_imu'] = imuSub;
  }

  Future<void> stopRecording() async {
    for (var sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _recordingTimer?.cancel();
    _recordingTimer = null;

    await ref.read(csvWritersProvider.notifier).closeAll();

    final config = ref.read(sessionConfigProvider);
    if (config != null && config.recordVideo) {
      final cameraService = ref.read(cameraRecordingServiceProvider);
      if (cameraService.isRecording) {
        final saved = await cameraService.stopRecording();
        if (saved != null) _videoFile = saved;
      }
    }

    ref.read(recordingStateProvider.notifier).stopRecording();
  }

  Future<void> pauseRecording() async {
    if (_isPaused) return;
    _isPaused = true;

    final config = ref.read(sessionConfigProvider);
    if (config != null && config.recordVideo) {
      final cameraService = ref.read(cameraRecordingServiceProvider);
      await cameraService.pauseRecording();
    }

    ref.read(recordingStateProvider.notifier).pauseRecording();
  }

  Future<void> resumeRecording() async {
    if (!_isPaused) return;

    final config = ref.read(sessionConfigProvider);
    if (config != null && config.recordVideo) {
      final cameraService = ref.read(cameraRecordingServiceProvider);
      await cameraService.resumeRecording();
    }

    _isPaused = false;
    ref.read(recordingStateProvider.notifier).resumeRecording();
  }

  void addTrigger() {
    final csvWriters = ref.read(csvWritersProvider);
    for (var writer in csvWriters.values) {
      writer.incrementTrigger();
    }
  }

  int get elapsedSeconds => _elapsedSeconds;
  DateTime? get sessionStartTime => _sessionStartTime;

  void dispose() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _recordingTimer?.cancel();
  }
}
