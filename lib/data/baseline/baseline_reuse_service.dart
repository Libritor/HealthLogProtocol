import 'dart:math' as math;

/// Result of reusing a baseline for arousal inference.
class BaselineReuseResult {
  final String arousalLabel; // "low" | "medium" | "high" | ...
  final double arousalIndex; // 0..1
  final int cluster;
  final Map<int, double> clusterProbabilities;

  const BaselineReuseResult({
    required this.arousalLabel,
    required this.arousalIndex,
    required this.cluster,
    required this.clusterProbabilities,
  });
}

/// The consumer side of a baseline: run inference from a *verified* baseline
/// without recording or re-calibrating anything.
///
/// Given a GMM baseline (the `GmmModelState` shape) and a raw feature vector, it
/// standardizes the features and evaluates full-covariance Gaussian mixture
/// responsibilities — the same log-Gaussian form the app's calibration uses
/// (sklearn's `_estimate_log_gaussian_prob`). This is what makes an anchored
/// baseline actually reusable, not just verifiable.
class BaselineReuseService {
  static const _levelScore = {'low': 0.0, 'medium': 0.5, 'high': 1.0};

  BaselineReuseResult classify(
    Map<String, dynamic> modelState,
    List<double> rawFeatures,
  ) {
    final scalerMean = _vec(modelState['scalerMean']);
    final scalerScale = _vec(modelState['scalerScale']);
    final weights = _vec(modelState['gmmWeights']);
    final means = _mat(modelState['gmmMeans']);
    final covs = _cube(modelState['gmmCovariances']);
    final clusterToArousal = (modelState['clusterToArousal'] as Map)
        .map((k, v) => MapEntry(k.toString(), v.toString()));

    final d = scalerMean.length;
    if (rawFeatures.length != d) {
      throw ArgumentError(
          'feature vector length ${rawFeatures.length} != baseline dim $d');
    }

    // Standardize with the baseline's own scaler.
    final z = List<double>.generate(
        d, (i) => (rawFeatures[i] - scalerMean[i]) / scalerScale[i]);

    final k = weights.length;
    final logProbs = List<double>.generate(
        k, (j) => math.log(weights[j]) + _mvnLogProb(z, means[j], covs[j]));

    // Softmax to responsibilities.
    final maxLog = logProbs.reduce(math.max);
    final exps = logProbs.map((l) => math.exp(l - maxLog)).toList();
    final sum = exps.reduce((a, b) => a + b);
    final probs = <int, double>{
      for (var j = 0; j < k; j++) j: exps[j] / sum,
    };

    var argmax = 0;
    for (var j = 1; j < k; j++) {
      if (probs[j]! > probs[argmax]!) argmax = j;
    }

    double index = 0;
    probs.forEach((cluster, p) {
      final level = clusterToArousal['$cluster'] ?? 'medium';
      index += p * (_levelScore[level] ?? 0.5);
    });

    return BaselineReuseResult(
      arousalLabel: clusterToArousal['$argmax'] ?? 'unknown',
      arousalIndex: index,
      cluster: argmax,
      clusterProbabilities: probs,
    );
  }

  // --- multivariate Gaussian, full covariance, via Cholesky ---

  double _mvnLogProb(
      List<double> x, List<double> mean, List<List<double>> cov) {
    final d = x.length;
    final diff = List<double>.generate(d, (i) => x[i] - mean[i]);
    final l = _cholesky(cov, ridge: 1e-9);

    var logDet = 0.0;
    for (var i = 0; i < d; i++) {
      logDet += math.log(l[i][i]);
    }
    logDet *= 2;

    // Solve L y = diff (forward substitution); quad = ||y||^2.
    final y = List<double>.filled(d, 0.0);
    for (var i = 0; i < d; i++) {
      var s = diff[i];
      for (var j = 0; j < i; j++) {
        s -= l[i][j] * y[j];
      }
      y[i] = s / l[i][i];
    }
    var quad = 0.0;
    for (var i = 0; i < d; i++) {
      quad += y[i] * y[i];
    }

    return -0.5 * (quad + logDet + d * math.log(2 * math.pi));
  }

  /// Cholesky decomposition of a symmetric positive-definite matrix (+ ridge).
  List<List<double>> _cholesky(List<List<double>> a, {double ridge = 0}) {
    final n = a.length;
    final l = List.generate(n, (_) => List<double>.filled(n, 0.0));
    for (var i = 0; i < n; i++) {
      for (var j = 0; j <= i; j++) {
        var s = a[i][j];
        if (i == j) s += ridge;
        for (var k = 0; k < j; k++) {
          s -= l[i][k] * l[j][k];
        }
        if (i == j) {
          l[i][j] = math.sqrt(s <= 0 ? (ridge > 0 ? ridge : 1e-9) : s);
        } else {
          l[i][j] = s / l[j][j];
        }
      }
    }
    return l;
  }

  List<double> _vec(dynamic l) =>
      (l as List).map((e) => (e as num).toDouble()).toList();
  List<List<double>> _mat(dynamic l) =>
      (l as List).map((r) => _vec(r)).toList();
  List<List<List<double>>> _cube(dynamic l) =>
      (l as List).map((m) => _mat(m)).toList();
}
