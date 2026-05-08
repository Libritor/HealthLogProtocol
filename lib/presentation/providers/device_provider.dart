import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/muse/muse_service.dart';
import '../../data/muse/muse_platform_repository.dart';
import '../../domain/models/muse_device.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/band_power_sample.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../domain/models/imu_sample.dart';

// Using real SDK bridge
final museServiceProvider = Provider<MuseService>((ref) {
  return MusePlatformRepository();
});

final deviceScanProvider = StreamProvider<List<MuseDevice>>((ref) {
  final museService = ref.watch(museServiceProvider);
  return museService.scanForDevices();
});

// Multi-device selection
final selectedDevicesProvider =
    StateNotifierProvider<SelectedDevicesNotifier, Set<String>>((ref) {
  return SelectedDevicesNotifier();
});

class SelectedDevicesNotifier extends StateNotifier<Set<String>> {
  SelectedDevicesNotifier() : super({});

  void toggleDevice(String deviceId) {
    if (state.contains(deviceId)) {
      state = Set.from(state)..remove(deviceId);
    } else {
      state = Set.from(state)..add(deviceId);
    }
  }

  void selectAll(List<String> deviceIds) {
    state = Set.from(deviceIds);
  }

  void clearSelection() {
    state = {};
  }
}

final connectedDevicesProvider =
    StateNotifierProvider<ConnectedDevicesNotifier, Map<String, MuseDevice>>(
        (ref) {
  return ConnectedDevicesNotifier();
});

class ConnectedDevicesNotifier
    extends StateNotifier<Map<String, MuseDevice>> {
  ConnectedDevicesNotifier() : super({});

  void addDevice(MuseDevice device) {
    state = {...state, device.id: device};
  }

  void removeDevice(String deviceId) {
    final newState = Map<String, MuseDevice>.from(state);
    newState.remove(deviceId);
    state = newState;
  }

  void updateDevice(MuseDevice device) {
    state = {...state, device.id: device};
  }

  void updateBattery(String deviceId, int battery) {
    final device = state[deviceId];
    if (device != null) {
      state = {...state, deviceId: device.copyWith(batteryPercent: battery)};
    }
  }

  void updateHsi(String deviceId, Map<String, HsiValue> hsiValues) {
    final device = state[deviceId];
    if (device != null) {
      state = {
        ...state,
        deviceId: device.copyWith(
          tp9Hsi: hsiValues['TP9'],
          af7Hsi: hsiValues['AF7'],
          af8Hsi: hsiValues['AF8'],
          tp10Hsi: hsiValues['TP10'],
        )
      };
    }
  }
}

// Auto-assigned display names: Muse1, Muse2, etc.
final deviceNamesProvider =
    StateNotifierProvider<DeviceNamesNotifier, Map<String, String>>((ref) {
  return DeviceNamesNotifier();
});

class DeviceNamesNotifier extends StateNotifier<Map<String, String>> {
  DeviceNamesNotifier() : super({});
  int _deviceCounter = 0;

  String assignName(String deviceId) {
    if (state.containsKey(deviceId)) {
      return state[deviceId]!;
    }
    
    _deviceCounter++;
    final name = 'Muse$_deviceCounter';
    state = {...state, deviceId: name};
    return name;
  }

  String getName(String deviceId) {
    if (!state.containsKey(deviceId)) {
      return assignName(deviceId);
    }
    return state[deviceId]!;
  }

  void rename(String deviceId, String newName) {
    if (newName.trim().isEmpty) return;
    state = {...state, deviceId: newName.trim()};
  }

  void removeName(String deviceId) {
    final newState = Map<String, String>.from(state);
    newState.remove(deviceId);
    state = newState;
  }

  void reset() {
    state = {};
    _deviceCounter = 0;
  }
}

// Per-device stream providers
final eegStreamProvider =
    StreamProvider.family<EegSample, String>((ref, deviceId) {
  final museService = ref.watch(museServiceProvider);
  return museService.subscribeToEeg(deviceId);
});

final bandPowerStreamProvider =
    StreamProvider.family<BandPowerSample, String>((ref, deviceId) {
  final museService = ref.watch(museServiceProvider);
  return museService.subscribeToBandPowers(deviceId);
});

final fnirsStreamProvider =
    StreamProvider.family<FnirsSample, String>((ref, deviceId) {
  final museService = ref.watch(museServiceProvider);
  return museService.subscribeToFnirs(deviceId);
});

final imuStreamProvider =
    StreamProvider.family<ImuSample, String>((ref, deviceId) {
  final museService = ref.watch(museServiceProvider);
  return museService.subscribeToImu(deviceId);
});

final batteryStreamProvider =
    StreamProvider.family<int, String>((ref, deviceId) {
  final museService = ref.watch(museServiceProvider);
  return museService.subscribeToBattery(deviceId);
});

final hsiStreamProvider =
    StreamProvider.family<Map<String, HsiValue>, String>((ref, deviceId) {
  final museService = ref.watch(museServiceProvider);
  return museService.subscribeToHsi(deviceId);
});
