import 'dart:io';
import 'package:osc/osc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OscOutputFormat {
  /// MuseLog legacy format: `/person{n}/eeg` with `[deltaAvg, thetaAvg, alphaAvg, betaAvg]`.
  muselog,

  /// SnowballArcade format: `/muse/elements/*_absolute` + `/muse/eeg`.
  ///
  /// This matches what SnowballArcade’s `MuseOSCManager` listens for.
  snowballArcade,
}

/// Provider for the OSC Service
final oscServiceProvider = Provider<OscService>((ref) {
  return OscService();
});

/// Provider for the target IP address - set this to your receiver (PC/VR) IP.
final oscTargetIpProvider = StateProvider<String>((ref) => '172.20.10.10');

/// Provider for the target Ports (default 5000).
final oscTargetPortsProvider = StateProvider<List<int>>((ref) => [5000]);

/// Provider for OSC message format.
final oscOutputFormatProvider =
    StateProvider<OscOutputFormat>((ref) => OscOutputFormat.snowballArcade);

/// Provider to toggle streaming on/off
final isOscStreamingProvider = StateProvider<bool>((ref) => false);

class OscService {
  RawDatagramSocket? _socket;

  OscService() {
    _initSocket();
  }

  Future<void> _initSocket() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      // Allow sending to broadcast addresses like 255.255.255.255 / 192.168.1.255.
      _socket!.broadcastEnabled = true;
    } catch (e) {
      print('Error binding OSC socket: $e');
    }
  }

  /// Send an OSC message to the target IP/Port
  void send(String address, List<Object> arguments, String targetIp, int targetPort) {
    if (_socket == null) {
      // Lazy-init if send happens before async bind completes.
      _initSocket();
      return;
    }

    try {
      final message = OSCMessage(address, arguments: arguments);
      final bytes = message.toBytes();
      
      _socket!.send(
        bytes,
        InternetAddress(targetIp),
        targetPort,
      );
    } catch (e) {
      print('Error sending OSC message: $e');
    }
  }

  void dispose() {
    _socket?.close();
  }
}
