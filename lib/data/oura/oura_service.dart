import '../../domain/models/oura_device.dart';
import '../../domain/models/oura_data.dart';

abstract class OuraService {
  Future<bool> isAuthenticated();

  Future<void> authenticate(String personalAccessToken);

  Future<void> signOut();

  Future<String?> getStoredToken();

  Future<OuraDevice> getDeviceInfo();

  Future<OuraDailySummary> getDailySummary(DateTime date);

  Future<List<OuraHeartRate>> getHeartRate({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<OuraHrvSample>> getHrv({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<OuraSleepData>> getSleep({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<OuraActivityData>> getActivity({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<OuraReadinessData>> getReadiness({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<OuraStressData>> getStress({
    required DateTime startDate,
    required DateTime endDate,
  });
}
