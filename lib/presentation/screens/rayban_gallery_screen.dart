import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/rayban_provider.dart';
import '../../domain/models/rayban_media.dart';

class RayBanGalleryScreen extends ConsumerWidget {
  const RayBanGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(raybanScannedMediaProvider);
    final selected = ref.watch(raybanSelectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ray-Ban Media'),
        actions: [
          if (selected.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                final files = selected
                    .map((p) => XFile(p))
                    .toList();
                Share.shareXFiles(
                  files,
                  subject: 'Ray-Ban Meta Media',
                );
              },
              icon: const Icon(Icons.share),
              label: Text('Share (${selected.length})'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'select_all') {
                ref
                    .read(raybanSelectedProvider.notifier)
                    .selectAll(mediaState.items);
              } else if (value == 'clear') {
                ref.read(raybanSelectedProvider.notifier).clearAll();
              } else if (value == 'scan') {
                ref.read(raybanScannedMediaProvider.notifier).scan();
              } else if (value == 'deep_scan') {
                ref
                    .read(raybanScannedMediaProvider.notifier)
                    .scan(deepScan: true);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'select_all', child: Text('Select All')),
              const PopupMenuItem(value: 'clear', child: Text('Clear Selection')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'scan', child: Text('Rescan')),
              const PopupMenuItem(value: 'deep_scan', child: Text('Deep Scan')),
            ],
          ),
        ],
      ),
      body: mediaState.isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for media files...'),
                ],
              ),
            )
          : mediaState.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('No media found'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(raybanScannedMediaProvider.notifier).scan();
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Scan for Media'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (selected.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Colors.blue.shade50,
                        child: Text(
                          '${selected.length} of ${mediaState.items.length} selected',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: mediaState.items.length,
                        itemBuilder: (context, index) {
                          final item = mediaState.items[index];
                          final isSelected = selected.contains(item.path);
                          return _MediaGridTile(
                            item: item,
                            isSelected: isSelected,
                            onTap: () => _openViewer(context, item),
                            onSelect: () {
                              ref
                                  .read(raybanSelectedProvider.notifier)
                                  .toggle(item.path);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _openViewer(BuildContext context, RayBanMediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MediaViewerScreen(item: item),
      ),
    );
  }
}

class _MediaGridTile extends StatelessWidget {
  final RayBanMediaItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  const _MediaGridTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onSelect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.isPhoto)
            Image.file(
              File(item.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 32),
              ),
            )
          else
            Container(
              color: Colors.grey[900],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill,
                      size: 40, color: Colors.white70),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      item.filename,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onSelect,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue
                      : Colors.black.withAlpha(100),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          if (item.isVideo)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.fileSizeFormatted,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaViewerScreen extends StatelessWidget {
  final RayBanMediaItem item;

  const _MediaViewerScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          item.filename,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Share.shareXFiles(
                [XFile(item.path)],
                subject: 'Ray-Ban Meta Media',
              );
            },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: Center(
        child: item.isPhoto
            ? InteractiveViewer(
                child: Image.file(
                  File(item.path),
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Colors.white54,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam, size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    item.filename,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.fileSizeFormatted,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Share.shareXFiles(
                        [XFile(item.path)],
                        subject: 'Ray-Ban Meta Video',
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Video'),
                  ),
                ],
              ),
      ),
    );
  }
}
