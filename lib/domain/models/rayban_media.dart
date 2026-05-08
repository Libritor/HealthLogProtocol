enum RayBanMediaType { photo, video }

class RayBanMediaItem {
  final String path;
  final String filename;
  final RayBanMediaType type;
  final DateTime createdAt;
  final int fileSize;

  const RayBanMediaItem({
    required this.path,
    required this.filename,
    required this.type,
    required this.createdAt,
    this.fileSize = 0,
  });

  String get extension => filename.split('.').last.toLowerCase();

  bool get isPhoto => type == RayBanMediaType.photo;
  bool get isVideo => type == RayBanMediaType.video;

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RayBanMediaItem &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
