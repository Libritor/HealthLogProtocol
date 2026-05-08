import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/rayban_media.dart';

class RayBanMediaService {
  static const _photoExtensions = {'.jpg', '.jpeg', '.png', '.heic', '.heif'};
  static const _videoExtensions = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};

  static const _knownDirectories = [
    'DCIM/RayBan',
    'DCIM/Facebook',
    'DCIM/Meta',
    'DCIM/Ray-Ban Stories',
    'DCIM/Meta View',
    'Pictures/RayBan',
    'Pictures/Meta',
    'Pictures/Facebook',
    'Pictures/Ray-Ban Stories',
    'Movies/RayBan',
    'Movies/Meta',
    'Movies/Facebook',
  ];

  static const _fallbackDirectories = [
    'DCIM',
    'Pictures',
    'Movies',
    'Download',
  ];

  Future<List<RayBanMediaItem>> scanForMedia({
    bool deepScan = false,
  }) async {
    final items = <RayBanMediaItem>[];
    final seen = <String>{};
    final storagePath = await _getExternalStoragePath();

    if (storagePath == null) return items;

    for (final subDir in _knownDirectories) {
      final dir = Directory('$storagePath/$subDir');
      if (await dir.exists()) {
        await _scanDirectory(dir, items, seen, recursive: true);
      }
    }

    if (items.isEmpty || deepScan) {
      for (final subDir in _fallbackDirectories) {
        final dir = Directory('$storagePath/$subDir');
        if (await dir.exists()) {
          await _scanDirectory(dir, items, seen, recursive: true);
        }
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<RayBanMediaItem>> pickMediaManually() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );

    if (result == null) return [];

    return result.files
        .where((f) => f.path != null)
        .map((f) {
      final file = File(f.path!);
      final ext = '.${f.extension?.toLowerCase() ?? ''}';
      final type = _videoExtensions.contains(ext)
          ? RayBanMediaType.video
          : RayBanMediaType.photo;
      return RayBanMediaItem(
        path: f.path!,
        filename: f.name,
        type: type,
        createdAt: file.existsSync()
            ? file.lastModifiedSync()
            : DateTime.now(),
        fileSize: f.size,
      );
    }).toList();
  }

  Future<List<File>> copyToSession(
    List<RayBanMediaItem> items, {
    DateTime? sessionStartTime,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = sessionStartTime ?? DateTime.now();
    final sessionDir = Directory(
      '${appDir.path}/muse_sessions/rayban_${timestamp.millisecondsSinceEpoch}',
    );
    await sessionDir.create(recursive: true);

    final copiedFiles = <File>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final source = File(item.path);
      if (!await source.exists()) continue;

      final destPath = '${sessionDir.path}/${item.filename}';
      final dest = await source.copy(destPath);
      copiedFiles.add(dest);
    }

    return copiedFiles;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<RayBanMediaItem> items,
    Set<String> seen, {
    bool recursive = false,
  }) async {
    try {
      await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
        if (entity is File) {
          final path = entity.path;
          if (seen.contains(path)) continue;

          final ext = '.${path.split('.').last.toLowerCase()}';
          RayBanMediaType? type;

          if (_photoExtensions.contains(ext)) {
            type = RayBanMediaType.photo;
          } else if (_videoExtensions.contains(ext)) {
            type = RayBanMediaType.video;
          }

          if (type != null) {
            seen.add(path);
            try {
              final stat = await entity.stat();
              items.add(RayBanMediaItem(
                path: path,
                filename: path.split('/').last,
                type: type,
                createdAt: stat.modified,
                fileSize: stat.size,
              ));
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<String?> _getExternalStoragePath() async {
    if (!Platform.isAndroid) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    return '/storage/emulated/0';
  }
}
