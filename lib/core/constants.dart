import 'package:flutter/material.dart';

class AppConstants {
  // Columns for standard MuseLog data collection CSV export.
  static const List<String> csvColumns = [
    'PACKET_TYPE',
    'DEVICE_NAME',
    'CLOCK_TIME',
    'ms_ELAPSED',
    'TRIGGER_COUNT',
    // HSI & Artifact Flags
    'TP9_CONNECTION_STRENGTH(HSI)',
    'TP9_ARTIFACT_FREE(IS_GOOD)',
    'AF7_CONNECTION_STRENGTH(HSI)',
    'AF7_ARTIFACT_FREE(IS_GOOD)',
    'AF8_CONNECTION_STRENGTH(HSI)',
    'AF8_ARTIFACT_FREE(IS_GOOD)',
    'TP10_CONNECTION_STRENGTH(HSI)',
    'TP10_ARTIFACT_FREE(IS_GOOD)',
    // Raw EEG (6 channels)
    'TP9_RAW',
    'AF7_RAW',
    'AF8_RAW',
    'TP10_RAW',
    'DRL',
    'REF',
    // Band Powers - Delta Absolute
    'TP9_DELTA_ABSOLUTE',
    'AF7_DELTA_ABSOLUTE',
    'AF8_DELTA_ABSOLUTE',
    'TP10_DELTA_ABSOLUTE',
    // Band Powers - Theta Absolute
    'TP9_THETA_ABSOLUTE',
    'AF7_THETA_ABSOLUTE',
    'AF8_THETA_ABSOLUTE',
    'TP10_THETA_ABSOLUTE',
    // Band Powers - Alpha Absolute
    'TP9_ALPHA_ABSOLUTE',
    'AF7_ALPHA_ABSOLUTE',
    'AF8_ALPHA_ABSOLUTE',
    'TP10_ALPHA_ABSOLUTE',
    // Band Powers - Beta Absolute
    'TP9_BETA_ABSOLUTE',
    'AF7_BETA_ABSOLUTE',
    'AF8_BETA_ABSOLUTE',
    'TP10_BETA_ABSOLUTE',
    // Band Powers - Gamma Absolute
    'TP9_GAMMA_ABSOLUTE',
    'AF7_GAMMA_ABSOLUTE',
    'AF8_GAMMA_ABSOLUTE',
    'TP10_GAMMA_ABSOLUTE',
    // Band Powers - Delta Relative
    'TP9_DELTA_RELATIVE',
    'AF7_DELTA_RELATIVE',
    'AF8_DELTA_RELATIVE',
    'TP10_DELTA_RELATIVE',
    // Band Powers - Theta Relative
    'TP9_THETA_RELATIVE',
    'AF7_THETA_RELATIVE',
    'AF8_THETA_RELATIVE',
    'TP10_THETA_RELATIVE',
    // Band Powers - Alpha Relative
    'TP9_ALPHA_RELATIVE',
    'AF7_ALPHA_RELATIVE',
    'AF8_ALPHA_RELATIVE',
    'TP10_ALPHA_RELATIVE',
    // Band Powers - Beta Relative
    'TP9_BETA_RELATIVE',
    'AF7_BETA_RELATIVE',
    'AF8_BETA_RELATIVE',
    'TP10_BETA_RELATIVE',
    // Band Powers - Gamma Relative
    'TP9_GAMMA_RELATIVE',
    'AF7_GAMMA_RELATIVE',
    'AF8_GAMMA_RELATIVE',
    'TP10_GAMMA_RELATIVE',
    // IMU
    'GYRO_X',
    'GYRO_Y',
    'GYRO_Z',
    'ACCEL_X',
    'ACCEL_Y',
    'ACCEL_Z',
    // fNIRS - 730nm
    '730nm_LEFT_OUTER',
    '730nm_RIGHT_OUTER',
    '850nm_LEFT_OUTER',
    '850nm_RIGHT_OUTER',
    '730nm_LEFT_INNER',
    '730nm_RIGHT_INNER',
    '850nm_LEFT_INNER',
    '850nm_RIGHT_INNER',
    // fNIRS - RED
    'RED_LEFT_OUTER',
    'RED_RIGHT_OUTER',
    'AMBIENT_LEFT_OUTER',
    'AMBIENT_RIGHT_OUTER',
    'RED_LEFT_INNER',
    'RED_RIGHT_INNER',
    'AMBIENT_LEFT_INNER',
    'AMBIENT_RIGHT_INNER',
    // Battery
    'BATTERY_PERCENT',
  ];

  // Column groups for UI selection
  static const Map<String, List<String>> columnGroups = {
    'Base Info': [
      'PACKET_TYPE',
      'DEVICE_NAME',
      'CLOCK_TIME',
      'ms_ELAPSED',
      'TRIGGER_COUNT',
    ],
    'HSI & Quality': [
      'TP9_CONNECTION_STRENGTH(HSI)',
      'TP9_ARTIFACT_FREE(IS_GOOD)',
      'AF7_CONNECTION_STRENGTH(HSI)',
      'AF7_ARTIFACT_FREE(IS_GOOD)',
      'AF8_CONNECTION_STRENGTH(HSI)',
      'AF8_ARTIFACT_FREE(IS_GOOD)',
      'TP10_CONNECTION_STRENGTH(HSI)',
      'TP10_ARTIFACT_FREE(IS_GOOD)',
    ],
    'EEG Raw': [
      'TP9_RAW',
      'AF7_RAW',
      'AF8_RAW',
      'TP10_RAW',
      'DRL',
      'REF',
    ],
    'Band Powers (Absolute)': [
      'TP9_DELTA_ABSOLUTE',
      'AF7_DELTA_ABSOLUTE',
      'AF8_DELTA_ABSOLUTE',
      'TP10_DELTA_ABSOLUTE',
      'TP9_THETA_ABSOLUTE',
      'AF7_THETA_ABSOLUTE',
      'AF8_THETA_ABSOLUTE',
      'TP10_THETA_ABSOLUTE',
      'TP9_ALPHA_ABSOLUTE',
      'AF7_ALPHA_ABSOLUTE',
      'AF8_ALPHA_ABSOLUTE',
      'TP10_ALPHA_ABSOLUTE',
      'TP9_BETA_ABSOLUTE',
      'AF7_BETA_ABSOLUTE',
      'AF8_BETA_ABSOLUTE',
      'TP10_BETA_ABSOLUTE',
      'TP9_GAMMA_ABSOLUTE',
      'AF7_GAMMA_ABSOLUTE',
      'AF8_GAMMA_ABSOLUTE',
      'TP10_GAMMA_ABSOLUTE',
    ],
    'Band Powers (Relative)': [
      'TP9_DELTA_RELATIVE',
      'AF7_DELTA_RELATIVE',
      'AF8_DELTA_RELATIVE',
      'TP10_DELTA_RELATIVE',
      'TP9_THETA_RELATIVE',
      'AF7_THETA_RELATIVE',
      'AF8_THETA_RELATIVE',
      'TP10_THETA_RELATIVE',
      'TP9_ALPHA_RELATIVE',
      'AF7_ALPHA_RELATIVE',
      'AF8_ALPHA_RELATIVE',
      'TP10_ALPHA_RELATIVE',
      'TP9_BETA_RELATIVE',
      'AF7_BETA_RELATIVE',
      'AF8_BETA_RELATIVE',
      'TP10_BETA_RELATIVE',
      'TP9_GAMMA_RELATIVE',
      'AF7_GAMMA_RELATIVE',
      'AF8_GAMMA_RELATIVE',
      'TP10_GAMMA_RELATIVE',
    ],
    'IMU': [
      'GYRO_X',
      'GYRO_Y',
      'GYRO_Z',
      'ACCEL_X',
      'ACCEL_Y',
      'ACCEL_Z',
    ],
    'fNIRS': [
      '730nm_LEFT_OUTER',
      '730nm_RIGHT_OUTER',
      '850nm_LEFT_OUTER',
      '850nm_RIGHT_OUTER',
      '730nm_LEFT_INNER',
      '730nm_RIGHT_INNER',
      '850nm_LEFT_INNER',
      '850nm_RIGHT_INNER',
      'RED_LEFT_OUTER',
      'RED_RIGHT_OUTER',
      'AMBIENT_LEFT_OUTER',
      'AMBIENT_RIGHT_OUTER',
      'RED_LEFT_INNER',
      'RED_RIGHT_INNER',
      'AMBIENT_LEFT_INNER',
      'AMBIENT_RIGHT_INNER',
    ],
    'Battery': ['BATTERY_PERCENT'],
  };

  // HSI (Horseshoe Signal Indicator) values and color mapping
  static const int hsiGood = 1;
  static const int hsiMedium = 2;
  static const int hsiBad = 4;

  static Color getHsiColor(int hsiValue) {
    if (hsiValue == hsiGood) {
      return Colors.green;
    } else if (hsiValue == hsiMedium) {
      return Colors.yellow.shade700;
    } else {
      // 3 or higher is typically considered bad/poor connection
      return Colors.red;
    }
  }

  // Sample rates (Hz)
  static const int eegSampleRate = 256;
  static const int fnirsSampleRate = 64;
  static const int imuSampleRate = 52;
  static const int batteryUpdateRate = 1; // Once per second

  // Chart display settings
  static const int eegDisplayWindowSeconds = 10;
  static const int eegDisplayDecimation =
      4; // Show every 4th sample for performance
  static const int fnirsDisplayWindowSeconds = 20;
  static const int imuDisplayWindowSeconds = 10;

  // EEG channel names
  static const List<String> eegChannels = ['TP9', 'AF7', 'AF8', 'TP10'];
  static const List<String> eegAuxChannels = ['DRL', 'REF'];

  // Band names
  static const List<String> bandNames = [
    'Delta',
    'Theta',
    'Alpha',
    'Beta',
    'Gamma'
  ];

  // AI/Arousal backend URL
  // Update this to point to your FastAPI backend
  static const String arousalBackendUrl = 'http://localhost:8000';
}
