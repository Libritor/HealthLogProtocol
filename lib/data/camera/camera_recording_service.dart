import 'dart:io';
import 'package:camera/camera.dart';
import '../storage/file_storage_helper.dart';

enum CameraRecordingState { idle, initializing, ready, recording, stopping, error }

class CameraRecordingService {
  CameraController? _controller;
  CameraRecordingState _state = CameraRecordingState.idle;
  String? _errorMessage;
  File? _outputFile;
  bool _landscapeMode = true;

  CameraRecordingState get state => _state;
  String? get errorMessage => _errorMessage;
  CameraController? get controller => _controller;
  File? get outputFile => _outputFile;
  bool get isRecording => _state == CameraRecordingState.recording;
  bool get isLandscape => _landscapeMode;

  Future<void> initialize({
    CameraLensDirection direction = CameraLensDirection.back,
    bool landscape = true,
  }) async {
    if (_controller != null) {
      await dispose();
    }

    _state = CameraRecordingState.initializing;
    _landscapeMode = landscape;

    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      _state = CameraRecordingState.ready;
    } catch (e) {
      _state = CameraRecordingState.error;
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> startRecording({
    required String deviceId,
    String? deviceName,
    DateTime? sessionStartTime,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw StateError('Camera not initialized');
    }

    _outputFile = await FileStorageHelper.generateVideoFilePath(
      deviceId,
      deviceName: deviceName,
      sessionStartTime: sessionStartTime,
    );

    await _controller!.startVideoRecording();
    _state = CameraRecordingState.recording;
  }

  Future<File?> stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return null;
    }

    _state = CameraRecordingState.stopping;

    try {
      final xfile = await _controller!.stopVideoRecording();

      if (_outputFile != null) {
        await _outputFile!.parent.create(recursive: true);
        final saved = await File(xfile.path).copy(_outputFile!.path);
        try { await File(xfile.path).delete(); } catch (_) {}
        _state = CameraRecordingState.ready;
        return saved;
      }

      _state = CameraRecordingState.ready;
      return File(xfile.path);
    } catch (e) {
      _state = CameraRecordingState.error;
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<void> pauseRecording() async {
    if (_controller == null) return;
    final value = _controller!.value;
    if (!value.isRecordingVideo || value.isRecordingPaused) return;
    try {
      await _controller!.pauseVideoRecording();
    } catch (_) {}
  }

  Future<void> resumeRecording() async {
    if (_controller == null) return;
    final value = _controller!.value;
    if (!value.isRecordingVideo || !value.isRecordingPaused) return;
    try {
      await _controller!.resumeVideoRecording();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (_controller != null) {
      if (_controller!.value.isRecordingVideo) {
        try {
          await _controller!.stopVideoRecording();
        } catch (_) {}
      }
      await _controller!.dispose();
      _controller = null;
    }
    _state = CameraRecordingState.idle;
  }
}
