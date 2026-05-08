import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/muse/osc_service.dart';
import '../../domain/models/band_power_sample.dart';
import 'device_provider.dart';
import 'recording_provider.dart';

/// Provider for the OSC Streaming Manager
final oscStreamingManagerProvider = Provider<OscStreamingManager>((ref) {
  return OscStreamingManager(ref);
});

class OscStreamingManager {
  final Ref ref;
  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};

  int _resolveTargetPort(int deviceIndex) {
    final targetPorts = ref.read(oscTargetPortsProvider);
    if (targetPorts.isEmpty) return 5000;
    if (targetPorts.length == 1) return targetPorts.first;
    return targetPorts[deviceIndex % targetPorts.length];
  }

  OscStreamingManager(this.ref) {
    // Listen to streaming toggle
    ref.listen(isOscStreamingProvider, (previous, isStreaming) {
      if (isStreaming) {
        _startStreaming();
      } else {
        _stopStreaming();
      }
    });
  }

  void _startStreaming() {
    // Prefer the session's selected device order (stable Person mapping).
    final config = ref.read(sessionConfigProvider);
    final deviceIds = config?.selectedDeviceIds ??
        ref.read(connectedDevicesProvider).keys.toList();
    
    // Subscribe to all connected devices with person mapping
    for (int i = 0; i < deviceIds.length; i++) {
      _subscribeToDevice(deviceIds[i], i);
    }
  }

  void _stopStreaming() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Subscribe to a device's band power stream and send OSC messages
  /// 
  /// [deviceId] - The device identifier
  /// [deviceIndex] - The device index (0 = Person 1, 1 = Person 2, etc.)
  void _subscribeToDevice(String deviceId, int deviceIndex) {
    final bandPowerKey = '$deviceId:bandPower';
    final hsiKey = '$deviceId:hsi';
    final eegKey = '$deviceId:eeg';
    if (_subscriptions.containsKey(bandPowerKey)) return;

    final oscService = ref.read(oscServiceProvider);
    
    // ============================================================================
    // 🎯 TARGET IP CONFIGURATION
    // ============================================================================
    // The target IP address is read from oscTargetIpProvider (default: '192.168.1.100')
    // Change this in the UI (OSC Settings dialog) or modify the default in osc_service.dart
    // ============================================================================
    
    // Subscribe directly to the MuseService broadcast stream
    // (Riverpod's StreamProvider.stream is unreliable from a Provider context)
    final museService = ref.read(museServiceProvider);
    final bandPowerSub = museService.subscribeToBandPowers(deviceId).listen((sample) {
      // ============================================================================
      // 🎯 READING TARGET IP FROM PROVIDER
      // ============================================================================
      // This is where your PC/VR IP address is retrieved
      final targetIp = ref.read(oscTargetIpProvider);
      if (targetIp.trim().isEmpty) return;
      
      final int targetPort = _resolveTargetPort(deviceIndex);

      final format = ref.read(oscOutputFormatProvider);
      switch (format) {
        case OscOutputFormat.muselog:
          final oscAddress = '/person${deviceIndex + 1}/eeg';

          // MuseLog legacy format: average across all 4 EEG channels.
          final bandPowers = _calculateAveragedBandPowers(sample);
          oscService.send(
            oscAddress,
            bandPowers,
            targetIp,
            targetPort,
          );
          break;
        case OscOutputFormat.snowballArcade:
          _sendSnowballArcadeBandPowersAbsolute(
            oscService: oscService,
            sample: sample,
            targetIp: targetIp,
            targetPort: targetPort,
          );
          break;
      }

    }, onError: (e) {
      print('Error streaming OSC for $deviceId: $e');
    });

    _subscriptions[bandPowerKey] = bandPowerSub;

    // Mind Monitor receivers often use horseshoe to decide if values are usable.
    final hsiSub = museService.subscribeToHsi(deviceId).listen((hsiMap) {
      final targetIp = ref.read(oscTargetIpProvider);
      if (targetIp.trim().isEmpty) return;

      final int targetPort = _resolveTargetPort(deviceIndex);

      final format = ref.read(oscOutputFormatProvider);
      if (format != OscOutputFormat.snowballArcade) return;

      // Mind Monitor: `/muse/elements/horseshoe` with 4 ints [TP9, AF7, AF8, TP10]
      oscService.send(
        '/muse/elements/horseshoe',
        [
          (hsiMap['TP9']?.value ?? 4),
          (hsiMap['AF7']?.value ?? 4),
          (hsiMap['AF8']?.value ?? 4),
          (hsiMap['TP10']?.value ?? 4),
        ],
        targetIp,
        targetPort,
      );
    }, onError: (e) {
      print('Error streaming OSC HSI for $deviceId: $e');
    });
    _subscriptions[hsiKey] = hsiSub;

    // Raw EEG stream: SnowballArcade can fall back to computing band powers from `/muse/eeg`.
    // Mind Monitor uses `/muse/eeg` with floats [TP9, AF7, AF8, TP10].
    var eegDecimate = 0;
    final eegSub = museService.subscribeToEeg(deviceId).listen((eeg) {
      final targetIp = ref.read(oscTargetIpProvider);
      if (targetIp.trim().isEmpty) return;

      final format = ref.read(oscOutputFormatProvider);
      if (format != OscOutputFormat.snowballArcade) return;

      // Raw EEG is ~256Hz. To reduce UDP/CPU load, send every 4th sample (~64Hz).
      eegDecimate = (eegDecimate + 1) % 4;
      if (eegDecimate != 0) return;

      final int targetPort = _resolveTargetPort(deviceIndex);

      oscService.send(
        '/muse/eeg',
        [eeg.tp9, eeg.af7, eeg.af8, eeg.tp10],
        targetIp,
        targetPort,
      );
    }, onError: (e) {
      print('Error streaming OSC EEG for $deviceId: $e');
    });
    _subscriptions[eegKey] = eegSub;
  }
  
  /// Calculate averaged band powers across all 4 EEG channels
  /// 
  /// Returns a list of 4 floats: [delta, theta, alpha, beta]
  /// All values are ABSOLUTE band powers (not relative)
  List<double> _calculateAveragedBandPowers(BandPowerSample sample) {
    // ============================================================================
    // 🎯 BAND POWER AVERAGING CALCULATION
    // ============================================================================
    // Each band (delta, theta, alpha, beta) is averaged across 4 channels:
    // TP9 (left ear), AF7 (left forehead), AF8 (right forehead), TP10 (right ear)
    // ============================================================================
    
    // Delta band (0.5-4 Hz) - deep sleep, unconscious processes
    final deltaAvg = (sample.tp9.deltaAbsolute + 
                      sample.af7.deltaAbsolute + 
                      sample.af8.deltaAbsolute + 
                      sample.tp10.deltaAbsolute) / 4.0;
    
    // Theta band (4-8 Hz) - meditation, creativity, intuition
    final thetaAvg = (sample.tp9.thetaAbsolute + 
                      sample.af7.thetaAbsolute + 
                      sample.af8.thetaAbsolute + 
                      sample.tp10.thetaAbsolute) / 4.0;
    
    // Alpha band (8-13 Hz) - relaxation, calmness, flow state
    final alphaAvg = (sample.tp9.alphaAbsolute + 
                      sample.af7.alphaAbsolute + 
                      sample.af8.alphaAbsolute + 
                      sample.tp10.alphaAbsolute) / 4.0;
    
    // Beta band (13-30 Hz) - focus, alertness, active thinking
    final betaAvg = (sample.tp9.betaAbsolute + 
                     sample.af7.betaAbsolute + 
                     sample.af8.betaAbsolute + 
                     sample.tp10.betaAbsolute) / 4.0;
    
    // Return in the order expected by Unity/VR: [delta, theta, alpha, beta]
    return [deltaAvg, thetaAvg, alphaAvg, betaAvg];
  }

  void _sendSnowballArcadeBandPowersAbsolute({
    required OscService oscService,
    required BandPowerSample sample,
    required String targetIp,
    required int targetPort,
  }) {
    // SnowballArcade listens for these OSC addresses and averages multiple args.
    // Send 4 values per message: [TP9, AF7, AF8, TP10]
    oscService.send(
      '/muse/elements/delta_absolute',
      [
        sample.tp9.deltaAbsolute,
        sample.af7.deltaAbsolute,
        sample.af8.deltaAbsolute,
        sample.tp10.deltaAbsolute,
      ],
      targetIp,
      targetPort,
    );
    oscService.send(
      '/muse/elements/theta_absolute',
      [
        sample.tp9.thetaAbsolute,
        sample.af7.thetaAbsolute,
        sample.af8.thetaAbsolute,
        sample.tp10.thetaAbsolute,
      ],
      targetIp,
      targetPort,
    );
    oscService.send(
      '/muse/elements/alpha_absolute',
      [
        sample.tp9.alphaAbsolute,
        sample.af7.alphaAbsolute,
        sample.af8.alphaAbsolute,
        sample.tp10.alphaAbsolute,
      ],
      targetIp,
      targetPort,
    );
    oscService.send(
      '/muse/elements/beta_absolute',
      [
        sample.tp9.betaAbsolute,
        sample.af7.betaAbsolute,
        sample.af8.betaAbsolute,
        sample.tp10.betaAbsolute,
      ],
      targetIp,
      targetPort,
    );
    oscService.send(
      '/muse/elements/gamma_absolute',
      [
        sample.tp9.gammaAbsolute,
        sample.af7.gammaAbsolute,
        sample.af8.gammaAbsolute,
        sample.tp10.gammaAbsolute,
      ],
      targetIp,
      targetPort,
    );
  }
  
  /// Refresh subscriptions (call when new device connects)
  void refreshSubscriptions() {
    if (ref.read(isOscStreamingProvider)) {
      _startStreaming();
    }
  }
}
