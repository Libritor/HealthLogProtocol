import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../../domain/models/oura_data.dart';
import 'file_storage_helper.dart';

class OuraCsvWriter {
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  File? _file;

  Future<File> writeSession(OuraDailySummary summary,
      {DateTime? sessionStartTime}) async {
    _file = await FileStorageHelper.generateOuraCsvFilePath(
      sessionStartTime: sessionStartTime,
    );
    await _file!.parent.create(recursive: true);

    final rows = <List<String>>[];

    rows.add([
      'TIMESTAMP',
      'DATA_TYPE',
      'METRIC',
      'VALUE',
      'UNIT',
    ]);

    if (summary.sleep != null) {
      final s = summary.sleep!;
      final day = DateFormat('yyyy-MM-dd').format(s.day);
      rows.add([day, 'SLEEP', 'SCORE', '${s.score}', 'score']);
      rows.add([
        day, 'SLEEP', 'TOTAL_SLEEP', '${s.totalSleepSeconds}', 'seconds'
      ]);
      rows.add(
          [day, 'SLEEP', 'REM_SLEEP', '${s.remSleepSeconds}', 'seconds']);
      rows.add([
        day, 'SLEEP', 'DEEP_SLEEP', '${s.deepSleepSeconds}', 'seconds'
      ]);
      rows.add([
        day, 'SLEEP', 'LIGHT_SLEEP', '${s.lightSleepSeconds}', 'seconds'
      ]);
      rows.add([
        day, 'SLEEP', 'AWAKE', '${s.awakeSleepSeconds}', 'seconds'
      ]);
      rows.add([
        day, 'SLEEP', 'LATENCY', '${s.latencySeconds}', 'seconds'
      ]);
      rows.add([
        day, 'SLEEP', 'EFFICIENCY', '${s.efficiency}', 'percent'
      ]);
      if (s.restingHeartRate > 0) {
        rows.add([
          day, 'SLEEP', 'RESTING_HEART_RATE', '${s.restingHeartRate}', 'bpm'
        ]);
      }
      if (s.averageHrv > 0) {
        rows.add([
          day, 'SLEEP', 'AVERAGE_HRV', '${s.averageHrv}', 'ms'
        ]);
      }
      if (s.bedtimeStart != null) {
        rows.add([day, 'SLEEP', 'BEDTIME_START', s.bedtimeStart!, '']);
      }
      if (s.bedtimeEnd != null) {
        rows.add([day, 'SLEEP', 'BEDTIME_END', s.bedtimeEnd!, '']);
      }
    }

    if (summary.activity != null) {
      final a = summary.activity!;
      final day = DateFormat('yyyy-MM-dd').format(a.day);
      rows.add([day, 'ACTIVITY', 'SCORE', '${a.score}', 'score']);
      rows.add(
          [day, 'ACTIVITY', 'STEPS', '${a.steps}', 'steps']);
      rows.add([
        day, 'ACTIVITY', 'ACTIVE_CALORIES', '${a.activeCalories}', 'kcal'
      ]);
      rows.add([
        day, 'ACTIVITY', 'TOTAL_CALORIES', '${a.totalCalories}', 'kcal'
      ]);
      rows.add([
        day,
        'ACTIVITY',
        'SEDENTARY_MINUTES',
        '${a.sedentaryMinutes}',
        'minutes'
      ]);
      rows.add([
        day,
        'ACTIVITY',
        'MEDIUM_ACTIVITY_MINUTES',
        '${a.mediumActivityMinutes}',
        'minutes'
      ]);
      rows.add([
        day,
        'ACTIVITY',
        'HIGH_ACTIVITY_MINUTES',
        '${a.highActivityMinutes}',
        'minutes'
      ]);
    }

    if (summary.readiness != null) {
      final r = summary.readiness!;
      final day = DateFormat('yyyy-MM-dd').format(r.day);
      rows.add([day, 'READINESS', 'SCORE', '${r.score}', 'score']);
      rows.add([
        day,
        'READINESS',
        'TEMPERATURE_DEVIATION',
        '${r.temperatureDeviation}',
        'score'
      ]);
      if (r.restingHeartRate != null) {
        rows.add([
          day, 'READINESS', 'RESTING_HEART_RATE', '${r.restingHeartRate}', 'score'
        ]);
      }
      if (r.hrvBalance != null) {
        rows.add([day, 'READINESS', 'HRV_BALANCE', '${r.hrvBalance}', 'score']);
      }
      if (r.previousDayActivity != null) {
        rows.add([day, 'READINESS', 'PREVIOUS_DAY_ACTIVITY', '${r.previousDayActivity}', 'score']);
      }
      if (r.sleepBalance != null) {
        rows.add([day, 'READINESS', 'SLEEP_BALANCE', '${r.sleepBalance}', 'score']);
      }
      if (r.previousNight != null) {
        rows.add([day, 'READINESS', 'PREVIOUS_NIGHT', '${r.previousNight}', 'score']);
      }
      if (r.recoveryIndex != null) {
        rows.add([day, 'READINESS', 'RECOVERY_INDEX', '${r.recoveryIndex}', 'score']);
      }
    }

    if (summary.stress != null) {
      final st = summary.stress!;
      final day = DateFormat('yyyy-MM-dd').format(st.day);
      rows.add([day, 'STRESS', 'DAY_SUMMARY', st.daySummary, '']);
      rows.add([
        day, 'STRESS', 'STRESS_HIGH', '${st.stressHighSeconds}', 'seconds'
      ]);
      rows.add([
        day, 'STRESS', 'RECOVERY_HIGH', '${st.recoveryHighSeconds}', 'seconds'
      ]);
    }

    for (final hr in summary.heartRates) {
      rows.add([
        _dateFmt.format(hr.timestamp.toLocal()),
        'HEART_RATE',
        'BPM',
        '${hr.bpm}',
        'bpm',
      ]);
    }

    for (final hrv in summary.hrvSamples) {
      rows.add([
        _dateFmt.format(hrv.timestamp.toLocal()),
        'HRV',
        'RMSSD',
        hrv.rmssd.toStringAsFixed(2),
        'ms',
      ]);
    }

    final csvConverter = const ListToCsvConverter();
    final csvString = csvConverter.convert(rows);
    await _file!.writeAsString(csvString);

    return _file!;
  }

  File? get file => _file;
}
