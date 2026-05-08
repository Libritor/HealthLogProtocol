class OuraHeartRate {
  final DateTime timestamp;
  final int bpm;
  final String source; // "awake", "rest", "sleep", etc.

  const OuraHeartRate({
    required this.timestamp,
    required this.bpm,
    this.source = 'awake',
  });
}

class OuraHrvSample {
  final DateTime timestamp;
  final double rmssd;

  const OuraHrvSample({
    required this.timestamp,
    required this.rmssd,
  });
}

class OuraSleepData {
  final String id;
  final DateTime day;
  final int score;
  final int totalSleepSeconds;
  final int remSleepSeconds;
  final int deepSleepSeconds;
  final int lightSleepSeconds;
  final int awakeSleepSeconds;
  final int latencySeconds;
  final double efficiency;
  final int restingHeartRate;
  final double averageHrv;
  final String? bedtimeStart;
  final String? bedtimeEnd;

  const OuraSleepData({
    required this.id,
    required this.day,
    required this.score,
    this.totalSleepSeconds = 0,
    this.remSleepSeconds = 0,
    this.deepSleepSeconds = 0,
    this.lightSleepSeconds = 0,
    this.awakeSleepSeconds = 0,
    this.latencySeconds = 0,
    this.efficiency = 0,
    this.restingHeartRate = 0,
    this.averageHrv = 0,
    this.bedtimeStart,
    this.bedtimeEnd,
  });
}

class OuraActivityData {
  final String id;
  final DateTime day;
  final int score;
  final int activeCalories;
  final int totalCalories;
  final int steps;
  final int activeMinutes;
  final int sedentaryMinutes;
  final int mediumActivityMinutes;
  final int highActivityMinutes;

  const OuraActivityData({
    required this.id,
    required this.day,
    required this.score,
    this.activeCalories = 0,
    this.totalCalories = 0,
    this.steps = 0,
    this.activeMinutes = 0,
    this.sedentaryMinutes = 0,
    this.mediumActivityMinutes = 0,
    this.highActivityMinutes = 0,
  });
}

class OuraReadinessData {
  final String id;
  final DateTime day;
  final int score;
  final int temperatureDeviation;
  final int? restingHeartRate;
  final int? hrvBalance;
  final int? bodyTemperature;
  final int? previousDayActivity;
  final int? sleepBalance;
  final int? previousNight;
  final int? recoveryIndex;

  const OuraReadinessData({
    required this.id,
    required this.day,
    required this.score,
    this.temperatureDeviation = 0,
    this.restingHeartRate,
    this.hrvBalance,
    this.bodyTemperature,
    this.previousDayActivity,
    this.sleepBalance,
    this.previousNight,
    this.recoveryIndex,
  });
}

class OuraStressData {
  final String id;
  final DateTime day;
  final int stressHighSeconds;
  final int recoveryHighSeconds;
  final String daySummary; // "restored", "normal", "stressful"

  const OuraStressData({
    required this.id,
    required this.day,
    this.stressHighSeconds = 0,
    this.recoveryHighSeconds = 0,
    this.daySummary = 'normal',
  });

  double get stressHighMinutes => stressHighSeconds / 60.0;
  double get recoveryHighMinutes => recoveryHighSeconds / 60.0;
}

class OuraDailySummary {
  final DateTime day;
  final OuraSleepData? sleep;
  final OuraActivityData? activity;
  final OuraReadinessData? readiness;
  final OuraStressData? stress;
  final List<OuraHeartRate> heartRates;
  final List<OuraHrvSample> hrvSamples;

  const OuraDailySummary({
    required this.day,
    this.sleep,
    this.activity,
    this.readiness,
    this.stress,
    this.heartRates = const [],
    this.hrvSamples = const [],
  });
}
