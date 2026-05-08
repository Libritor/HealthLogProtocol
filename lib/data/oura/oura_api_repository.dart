import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../domain/models/oura_device.dart';
import '../../domain/models/oura_data.dart';
import 'oura_service.dart';

class OuraApiRepository implements OuraService {
  static const _baseUrl = 'https://api.ouraring.com';
  static const _tokenKey = 'oura_personal_access_token';

  String? _cachedToken;

  Map<String, String> _headers() {
    if (_cachedToken == null) {
      throw StateError('Not authenticated with Oura. Call authenticate() first.');
    }
    return {
      'Authorization': 'Bearer $_cachedToken',
      'Content-Type': 'application/json',
    };
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Future<bool> isAuthenticated() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> authenticate(String personalAccessToken) async {
    final testResponse = await http.get(
      Uri.parse('$_baseUrl/v2/usercollection/personal_info'),
      headers: {
        'Authorization': 'Bearer $personalAccessToken',
        'Content-Type': 'application/json',
      },
    );

    if (testResponse.statusCode != 200) {
      throw Exception('Invalid Oura token (HTTP ${testResponse.statusCode})');
    }

    _cachedToken = personalAccessToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, personalAccessToken);
  }

  @override
  Future<void> signOut() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  @override
  Future<String?> getStoredToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> _ensureAuthenticated() async {
    if (_cachedToken == null) {
      final token = await getStoredToken();
      if (token == null) {
        throw StateError('Not authenticated with Oura.');
      }
    }
  }

  @override
  Future<OuraDevice> getDeviceInfo() async {
    await _ensureAuthenticated();

    final response = await http.get(
      Uri.parse('$_baseUrl/v2/usercollection/personal_info'),
      headers: _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get Oura device info (HTTP ${response.statusCode})');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    return OuraDevice(
      id: 'oura_ring_3',
      name: 'Oura Ring 3',
      isConnected: true,
      email: data['email'] as String?,
    );
  }

  @override
  Future<OuraDailySummary> getDailySummary(DateTime date) async {
    final results = await Future.wait([
      getSleep(startDate: date, endDate: date),
      getActivity(startDate: date, endDate: date),
      getReadiness(startDate: date, endDate: date),
      getHeartRate(startDate: date, endDate: date),
      getHrv(startDate: date, endDate: date),
      getStress(startDate: date, endDate: date),
    ]);

    final sleepList = results[0] as List<OuraSleepData>;
    final activityList = results[1] as List<OuraActivityData>;
    final readinessList = results[2] as List<OuraReadinessData>;
    final heartRates = results[3] as List<OuraHeartRate>;
    final hrvSamples = results[4] as List<OuraHrvSample>;
    final stressList = results[5] as List<OuraStressData>;

    return OuraDailySummary(
      day: date,
      sleep: sleepList.isNotEmpty ? sleepList.first : null,
      activity: activityList.isNotEmpty ? activityList.first : null,
      readiness: readinessList.isNotEmpty ? readinessList.first : null,
      stress: stressList.isNotEmpty ? stressList.first : null,
      heartRates: heartRates,
      hrvSamples: hrvSamples,
    );
  }

  @override
  Future<List<OuraHeartRate>> getHeartRate({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse(
      '$_baseUrl/v2/usercollection/heartrate'
      '?start_datetime=${startDate.toIso8601String()}'
      '&end_datetime=${endDate.add(const Duration(days: 1)).toIso8601String()}',
    );

    final response = await http.get(uri, headers: _headers());

    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];

    return data.map((item) {
      final map = item as Map<String, dynamic>;
      return OuraHeartRate(
        timestamp: DateTime.parse(map['timestamp'] as String),
        bpm: map['bpm'] as int,
        source: map['source'] as String? ?? 'unknown',
      );
    }).toList();
  }

  @override
  Future<List<OuraHrvSample>> getHrv({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse(
      '$_baseUrl/v2/usercollection/heartrate'
      '?start_datetime=${startDate.toIso8601String()}'
      '&end_datetime=${endDate.add(const Duration(days: 1)).toIso8601String()}',
    );

    final response = await http.get(uri, headers: _headers());

    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];

    return data
        .where((item) => (item as Map<String, dynamic>).containsKey('hrv'))
        .map((item) {
      final map = item as Map<String, dynamic>;
      return OuraHrvSample(
        timestamp: DateTime.parse(map['timestamp'] as String),
        rmssd: (map['hrv'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Future<List<OuraSleepData>> getSleep({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse(
      '$_baseUrl/v2/usercollection/daily_sleep'
      '?start_date=${_formatDate(startDate)}'
      '&end_date=${_formatDate(endDate)}',
    );

    final response = await http.get(uri, headers: _headers());

    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];

    return data.map((item) {
      final map = item as Map<String, dynamic>;
      final contributors = map['contributors'] as Map<String, dynamic>? ?? {};

      return OuraSleepData(
        id: map['id'] as String? ?? '',
        day: DateTime.parse(map['day'] as String),
        score: map['score'] as int? ?? 0,
        totalSleepSeconds: contributors['total_sleep'] as int? ?? 0,
        remSleepSeconds: contributors['rem_sleep'] as int? ?? 0,
        deepSleepSeconds: contributors['deep_sleep'] as int? ?? 0,
        efficiency: (contributors['efficiency'] as num?)?.toDouble() ?? 0,
        restingHeartRate: contributors['resting_heart_rate'] as int? ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<OuraActivityData>> getActivity({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse(
      '$_baseUrl/v2/usercollection/daily_activity'
      '?start_date=${_formatDate(startDate)}'
      '&end_date=${_formatDate(endDate)}',
    );

    final response = await http.get(uri, headers: _headers());

    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];

    return data.map((item) {
      final map = item as Map<String, dynamic>;

      return OuraActivityData(
        id: map['id'] as String? ?? '',
        day: DateTime.parse(map['day'] as String),
        score: map['score'] as int? ?? 0,
        activeCalories: map['active_calories'] as int? ?? 0,
        totalCalories: map['total_calories'] as int? ?? 0,
        steps: map['steps'] as int? ?? 0,
        sedentaryMinutes: ((map['sedentary_time'] as int?) ?? 0) ~/ 60,
        mediumActivityMinutes:
            ((map['medium_activity_time'] as int?) ?? 0) ~/ 60,
        highActivityMinutes:
            ((map['high_activity_time'] as int?) ?? 0) ~/ 60,
      );
    }).toList();
  }

  @override
  Future<List<OuraReadinessData>> getReadiness({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse(
      '$_baseUrl/v2/usercollection/daily_readiness'
      '?start_date=${_formatDate(startDate)}'
      '&end_date=${_formatDate(endDate)}',
    );

    final response = await http.get(uri, headers: _headers());

    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];

    return data.map((item) {
      final map = item as Map<String, dynamic>;
      final contributors = map['contributors'] as Map<String, dynamic>? ?? {};

      return OuraReadinessData(
        id: map['id'] as String? ?? '',
        day: DateTime.parse(map['day'] as String),
        score: map['score'] as int? ?? 0,
        temperatureDeviation:
            contributors['body_temperature'] as int? ?? 0,
        restingHeartRate:
            contributors['resting_heart_rate'] as int?,
        hrvBalance: contributors['hrv_balance'] as int?,
        bodyTemperature: contributors['body_temperature'] as int?,
        previousDayActivity: contributors['previous_day_activity'] as int?,
        sleepBalance: contributors['sleep_balance'] as int?,
        previousNight: contributors['previous_night'] as int?,
        recoveryIndex: contributors['recovery_index'] as int?,
      );
    }).toList();
  }

  @override
  Future<List<OuraStressData>> getStress({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse(
      '$_baseUrl/v2/usercollection/daily_stress'
      '?start_date=${_formatDate(startDate)}'
      '&end_date=${_formatDate(endDate)}',
    );

    final response = await http.get(uri, headers: _headers());

    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];

    return data.map((item) {
      final map = item as Map<String, dynamic>;
      return OuraStressData(
        id: map['id'] as String? ?? '',
        day: DateTime.parse(map['day'] as String),
        stressHighSeconds: map['stress_high'] as int? ?? 0,
        recoveryHighSeconds: map['recovery_high'] as int? ?? 0,
        daySummary: map['day_summary'] as String? ?? 'normal',
      );
    }).toList();
  }
}
