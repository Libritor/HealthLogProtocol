import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/oura/oura_service.dart';
import '../../data/oura/oura_api_repository.dart';
import '../../domain/models/oura_device.dart';
import '../../domain/models/oura_data.dart';

final ouraServiceProvider = Provider<OuraService>((ref) {
  return OuraApiRepository();
});

final ouraAuthStateProvider =
    StateNotifierProvider<OuraAuthNotifier, OuraAuthState>((ref) {
  return OuraAuthNotifier(ref.watch(ouraServiceProvider));
});

enum OuraConnectionStatus { disconnected, connecting, connected, error }

class OuraAuthState {
  final OuraConnectionStatus status;
  final OuraDevice? device;
  final String? errorMessage;

  const OuraAuthState({
    this.status = OuraConnectionStatus.disconnected,
    this.device,
    this.errorMessage,
  });

  OuraAuthState copyWith({
    OuraConnectionStatus? status,
    OuraDevice? device,
    String? errorMessage,
  }) {
    return OuraAuthState(
      status: status ?? this.status,
      device: device ?? this.device,
      errorMessage: errorMessage,
    );
  }
}

class OuraAuthNotifier extends StateNotifier<OuraAuthState> {
  final OuraService _service;

  OuraAuthNotifier(this._service) : super(const OuraAuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _service.getStoredToken();
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(status: OuraConnectionStatus.connecting);
      try {
        final device = await _service.getDeviceInfo();
        state = OuraAuthState(
          status: OuraConnectionStatus.connected,
          device: device,
        );
      } catch (_) {
        await _service.signOut();
        state = const OuraAuthState(
          status: OuraConnectionStatus.disconnected,
        );
      }
    }
  }

  Future<void> authenticate(String token) async {
    state = state.copyWith(
      status: OuraConnectionStatus.connecting,
      errorMessage: null,
    );

    try {
      await _service.authenticate(token);
      final device = await _service.getDeviceInfo();
      state = OuraAuthState(
        status: OuraConnectionStatus.connected,
        device: device,
      );
    } catch (e) {
      state = OuraAuthState(
        status: OuraConnectionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const OuraAuthState(
      status: OuraConnectionStatus.disconnected,
    );
  }
}

final ouraDailySummaryProvider =
    FutureProvider.family<OuraDailySummary, DateTime>((ref, date) async {
  final service = ref.watch(ouraServiceProvider);
  return service.getDailySummary(date);
});
