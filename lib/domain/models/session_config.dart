class SessionConfig {
  final List<String> selectedDeviceIds;
  final Set<String> selectedColumns;
  final String sessionName;
  final String notes;
  final DateTime startTime;
  final bool recordVideo;
  final bool includeOura;
  final bool includeRayBan;
  final List<String> raybanMediaPaths;

  const SessionConfig({
    required this.selectedDeviceIds,
    required this.selectedColumns,
    required this.sessionName,
    this.notes = '',
    required this.startTime,
    this.recordVideo = false,
    this.includeOura = false,
    this.includeRayBan = false,
    this.raybanMediaPaths = const [],
  });

  bool get hasMuseDevices => selectedDeviceIds.isNotEmpty;

  SessionConfig copyWith({
    List<String>? selectedDeviceIds,
    Set<String>? selectedColumns,
    String? sessionName,
    String? notes,
    DateTime? startTime,
    bool? recordVideo,
    bool? includeOura,
    bool? includeRayBan,
    List<String>? raybanMediaPaths,
  }) {
    return SessionConfig(
      selectedDeviceIds: selectedDeviceIds ?? this.selectedDeviceIds,
      selectedColumns: selectedColumns ?? this.selectedColumns,
      sessionName: sessionName ?? this.sessionName,
      notes: notes ?? this.notes,
      startTime: startTime ?? this.startTime,
      recordVideo: recordVideo ?? this.recordVideo,
      includeOura: includeOura ?? this.includeOura,
      includeRayBan: includeRayBan ?? this.includeRayBan,
      raybanMediaPaths: raybanMediaPaths ?? this.raybanMediaPaths,
    );
  }
}

enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
}

// User-placed marker during recording.
class TriggerEvent {
  final DateTime timestamp;
  final int triggerCount;
  final String? note;

  const TriggerEvent({
    required this.timestamp,
    required this.triggerCount,
    this.note,
  });
}
