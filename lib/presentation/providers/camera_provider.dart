import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/camera/camera_recording_service.dart';

enum VideoOrientation { landscape, portrait }

final cameraRecordingServiceProvider =
    Provider<CameraRecordingService>((ref) {
  final service = CameraRecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});

final recordVideoEnabledProvider = StateProvider<bool>((ref) => false);

final selectedCameraDirectionProvider =
    StateProvider<CameraLensDirection>((ref) => CameraLensDirection.back);

final selectedVideoOrientationProvider =
    StateProvider<VideoOrientation>((ref) => VideoOrientation.landscape);
