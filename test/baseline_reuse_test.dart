import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthlog/data/baseline/baseline_reuse_service.dart';

/// The payoff test: a consumer runs arousal inference from a baseline it did
/// NOT record. Feature vectors that standardize to a cluster's mean must
/// classify to that cluster's arousal label.
void main() {
  final service = BaselineReuseService();

  final modelState = (jsonDecode(File(
              'tools/baseline_anchor/samples/eeg_gmm_arousal.json')
          .readAsStringSync()) as Map<String, dynamic>)['baseline']
      as Map<String, dynamic>;

  final scalerMean = (modelState['scalerMean'] as List)
      .map((e) => (e as num).toDouble())
      .toList();
  final scalerScale = (modelState['scalerScale'] as List)
      .map((e) => (e as num).toDouble())
      .toList();

  // Raw features that, after the baseline's own standardization, land on a
  // given standardized target z.
  List<double> rawFor(List<double> z) =>
      List.generate(z.length, (i) => scalerMean[i] + z[i] * scalerScale[i]);

  test('features at the high-cluster mean classify as high', () {
    final r = service.classify(modelState, rawFor([0.79, -0.61, 0.55, 0.83]));
    expect(r.arousalLabel, 'high');
    expect(r.cluster, 2);
    expect(r.arousalIndex, greaterThan(0.6));
  });

  test('features at the low-cluster mean classify as low', () {
    final r = service.classify(modelState, rawFor([-0.81, 0.62, -0.44, -0.70]));
    expect(r.arousalLabel, 'low');
    expect(r.cluster, 0);
    expect(r.arousalIndex, lessThan(0.4));
  });

  test('responsibilities form a valid distribution', () {
    final r = service.classify(modelState, rawFor([0.1, -0.05, 0.08, 0.02]));
    final total =
        r.clusterProbabilities.values.fold<double>(0, (a, b) => a + b);
    expect(total, closeTo(1.0, 1e-9));
    expect(r.arousalLabel, 'medium');
  });

  test('a wrong-length feature vector is rejected', () {
    expect(() => service.classify(modelState, [1, 2, 3]), throwsArgumentError);
  });
}
