import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/rayban/rayban_media_service.dart';
import '../../domain/models/rayban_media.dart';

final raybanMediaServiceProvider = Provider<RayBanMediaService>((ref) {
  return RayBanMediaService();
});

final raybanScannedMediaProvider =
    StateNotifierProvider<RayBanMediaNotifier, RayBanMediaState>((ref) {
  return RayBanMediaNotifier(ref.read(raybanMediaServiceProvider));
});

class RayBanMediaState {
  final List<RayBanMediaItem> items;
  final bool isScanning;
  final String? error;

  const RayBanMediaState({
    this.items = const [],
    this.isScanning = false,
    this.error,
  });

  RayBanMediaState copyWith({
    List<RayBanMediaItem>? items,
    bool? isScanning,
    String? error,
  }) {
    return RayBanMediaState(
      items: items ?? this.items,
      isScanning: isScanning ?? this.isScanning,
      error: error,
    );
  }
}

class RayBanMediaNotifier extends StateNotifier<RayBanMediaState> {
  final RayBanMediaService _service;

  RayBanMediaNotifier(this._service) : super(const RayBanMediaState());

  Future<void> scan({bool deepScan = false}) async {
    state = state.copyWith(isScanning: true, error: null);
    try {
      final items = await _service.scanForMedia(deepScan: deepScan);
      state = state.copyWith(items: items, isScanning: false);
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  Future<void> pickManually() async {
    try {
      final picked = await _service.pickMediaManually();
      if (picked.isEmpty) return;

      final existing = state.items.map((i) => i.path).toSet();
      final newItems = picked.where((i) => !existing.contains(i.path)).toList();
      if (newItems.isNotEmpty) {
        final combined = [...state.items, ...newItems];
        combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(items: combined);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void removeItem(RayBanMediaItem item) {
    state = state.copyWith(
      items: state.items.where((i) => i.path != item.path).toList(),
    );
  }
}

final raybanSelectedProvider =
    StateNotifierProvider<RayBanSelectedNotifier, Set<String>>((ref) {
  return RayBanSelectedNotifier();
});

class RayBanSelectedNotifier extends StateNotifier<Set<String>> {
  RayBanSelectedNotifier() : super({});

  void toggle(String path) {
    if (state.contains(path)) {
      state = Set.from(state)..remove(path);
    } else {
      state = Set.from(state)..add(path);
    }
  }

  void selectAll(List<RayBanMediaItem> items) {
    state = items.map((i) => i.path).toSet();
  }

  void clearAll() {
    state = {};
  }

  bool isSelected(String path) => state.contains(path);
}

final raybanAttachedFilesProvider =
    StateNotifierProvider<RayBanAttachedNotifier, List<File>>((ref) {
  return RayBanAttachedNotifier();
});

class RayBanAttachedNotifier extends StateNotifier<List<File>> {
  RayBanAttachedNotifier() : super([]);

  void setFiles(List<File> files) {
    state = files;
  }

  void addFiles(List<File> files) {
    state = [...state, ...files];
  }

  void clear() {
    state = [];
  }
}
