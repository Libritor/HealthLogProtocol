import 'package:flutter_test/flutter_test.dart';
import 'package:healthlog/core/constants.dart';
import 'package:healthlog/domain/models/muse_device.dart';
import 'package:healthlog/domain/models/eeg_sample.dart';
import 'package:healthlog/domain/models/band_power_sample.dart';
import 'package:flutter/material.dart';

void main() {
  group('HSI Color Mapping Tests', () {
    test('HSI value 1 should map to green', () {
      final color = AppConstants.getHsiColor(1);
      expect(color, Colors.green);
    });

    test('HSI value 2 should map to yellow', () {
      final color = AppConstants.getHsiColor(2);
      expect(color, Colors.yellow.shade700);
    });

    test('HSI value 4 should map to red', () {
      final color = AppConstants.getHsiColor(4);
      expect(color, Colors.red);
    });

    test('Unknown HSI value should map to grey', () {
      final color = AppConstants.getHsiColor(99);
      expect(color, Colors.grey);
    });
  });

  group('CSV Column Schema Tests', () {
    test('CSV columns should have exactly 81 columns', () {
      expect(AppConstants.csvColumns.length, 81);
    });

    test('CSV columns should include base info columns', () {
      expect(AppConstants.csvColumns, contains('PACKET_TYPE'));
      expect(AppConstants.csvColumns, contains('CLOCK_TIME'));
      expect(AppConstants.csvColumns, contains('ms_ELAPSED'));
      expect(AppConstants.csvColumns, contains('TRIGGER_COUNT'));
    });

    test('CSV columns should include all EEG raw channels', () {
      expect(AppConstants.csvColumns, contains('TP9_RAW'));
      expect(AppConstants.csvColumns, contains('AF7_RAW'));
      expect(AppConstants.csvColumns, contains('AF8_RAW'));
      expect(AppConstants.csvColumns, contains('TP10_RAW'));
      expect(AppConstants.csvColumns, contains('DRL'));
      expect(AppConstants.csvColumns, contains('REF'));
    });

    test('CSV columns should include fNIRS channels', () {
      expect(AppConstants.csvColumns, contains('730nm_LEFT_OUTER'));
      expect(AppConstants.csvColumns, contains('850nm_RIGHT_INNER'));
      expect(AppConstants.csvColumns, contains('RED_LEFT_OUTER'));
      expect(AppConstants.csvColumns, contains('AMBIENT_RIGHT_INNER'));
    });

    test('CSV columns should include battery', () {
      expect(AppConstants.csvColumns, contains('BATTERY_PERCENT'));
    });
  });

  group('EegSample CSV Conversion Tests', () {
    test('EegSample should convert to CSV map correctly', () {
      final sample = EegSample(
        timestamp: DateTime.now(),
        tp9: 10.5,
        af7: 20.3,
        af8: -5.7,
        tp10: 15.2,
        drl: 0.1,
        ref: 0.2,
      );

      final csvValues = sample.toCsvValues();

      expect(csvValues['TP9_RAW'], '10.500000');
      expect(csvValues['AF7_RAW'], '20.300000');
      expect(csvValues['AF8_RAW'], '-5.700000');
      expect(csvValues['TP10_RAW'], '15.200000');
      expect(csvValues['DRL'], '0.100000');
      expect(csvValues['REF'], '0.200000');
    });
  });

  group('BandPowerSample CSV Conversion Tests', () {
    test('BandPowerSample should include all 40 band power columns', () {
      final channelPower = ChannelBandPower(
        deltaAbsolute: 1.0,
        thetaAbsolute: 2.0,
        alphaAbsolute: 3.0,
        betaAbsolute: 4.0,
        gammaAbsolute: 5.0,
        deltaRelative: 0.1,
        thetaRelative: 0.2,
        alphaRelative: 0.3,
        betaRelative: 0.25,
        gammaRelative: 0.15,
      );

      final sample = BandPowerSample(
        timestamp: DateTime.now(),
        tp9: channelPower,
        af7: channelPower,
        af8: channelPower,
        tp10: channelPower,
      );

      final csvValues = sample.toCsvValues();

      // Should have 40 entries (5 bands × 2 types × 4 channels)
      expect(csvValues.length, 40);

      // Spot check some values
      expect(csvValues['TP9_DELTA_ABSOLUTE'], '1.000000');
      expect(csvValues['AF7_ALPHA_RELATIVE'], '0.300000');
      expect(csvValues['TP10_GAMMA_ABSOLUTE'], '5.000000');
    });
  });

  group('MuseDevice Tests', () {
    test('MuseDevice equality should be based on ID', () {
      final device1 = MuseDevice(id: 'MUSE-1', name: 'Muse S');
      final device2 = MuseDevice(id: 'MUSE-1', name: 'Different Name');
      final device3 = MuseDevice(id: 'MUSE-2', name: 'Muse S');

      expect(device1, equals(device2)); // Same ID
      expect(device1, isNot(equals(device3))); // Different ID
    });

    test('MuseDevice copyWith should preserve unchanged values', () {
      final device = MuseDevice(
        id: 'MUSE-1',
        name: 'Muse S',
        batteryPercent: 75,
        isConnected: true,
      );

      final updated = device.copyWith(batteryPercent: 80);

      expect(updated.id, 'MUSE-1');
      expect(updated.name, 'Muse S');
      expect(updated.batteryPercent, 80);
      expect(updated.isConnected, true);
    });
  });

  group('Column Group Tests', () {
    test('All column groups should reference valid columns', () {
      final allColumnsSet = Set.from(AppConstants.csvColumns);

      for (var group in AppConstants.columnGroups.values) {
        for (var column in group) {
          expect(
            allColumnsSet.contains(column),
            true,
            reason: 'Column "$column" in group is not in csvColumns list',
          );
        }
      }
    });

    test('All columns should belong to at least one group', () {
      final allGroupColumns = AppConstants.columnGroups.values
          .expand((list) => list)
          .toSet();

      for (var column in AppConstants.csvColumns) {
        expect(
          allGroupColumns.contains(column),
          true,
          reason: 'Column "$column" is not in any group',
        );
      }
    });
  });
}
