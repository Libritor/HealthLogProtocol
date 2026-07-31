import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/models/baseline_models.dart';
import '../crypto/hashing_service.dart';

/// Builds [WearableBaseline] objects and enforces the on-chain privacy gate.
///
/// The commitment is a SHA-256 over the canonical (recursively key-sorted) JSON
/// of the fitted parameters, using the same [HashingService.canonicalJson] rule
/// as the rest of the app and the Node reference tool. This is what makes a
/// baseline verifiable without ever revealing it.
class BaselineHashing {
  static const _uuid = Uuid();
  final HashingService _hashing;

  BaselineHashing(this._hashing);

  /// Compute hashes and assemble a local (not-yet-anchored) baseline.
  ///
  /// [parameters] is the private, fitted calibration (GMM state, MVC levels,
  /// HRV norms). It is hashed but never stored on-chain.
  WearableBaseline build({
    required BaselineSignalType signal,
    required String model,
    required String modelVersion,
    required String featureSchema,
    required Map<String, dynamic> parameters,
    Map<String, dynamic>? featureSchemaSpec,
    Map<String, int> dims = const {},
    int? recordedSeconds,
    DateTime? validUntil,
    String? ownerWallet,
    DateTime? createdAt,
  }) {
    final baselineHash = hashParameters(parameters);
    final featureSchemaHash = featureSchemaSpec == null
        ? null
        : _hashing.hashString(canonicalSerialize(featureSchemaSpec));

    return WearableBaseline(
      baselineId: _uuid.v4(),
      ownerWallet: ownerWallet,
      signalType: signal,
      model: model,
      modelVersion: modelVersion,
      featureSchema: featureSchema,
      baselineHash: baselineHash,
      featureSchemaHash: featureSchemaHash,
      dims: dims,
      recordedSeconds: recordedSeconds,
      validUntil: validUntil,
      createdAt: createdAt ?? DateTime.now(),
      parameters: parameters,
    );
  }

  /// Build an EEG baseline directly from a serialized GMM model state — the
  /// real output of [GmmCalibrationService] (`CalibrationResult.modelState`).
  /// This is what turns "my actual calibration" into an anchorable, portable
  /// baseline instead of demo parameters.
  WearableBaseline fromModelStateJson(
    Map<String, dynamic> modelState, {
    int? recordedSeconds,
    DateTime? validUntil,
    String? ownerWallet,
    DateTime? createdAt,
  }) {
    final features = (modelState['featureCols'] as List?)?.length ??
        (modelState['scalerMean'] as List?)?.length ??
        0;
    final clusters = (modelState['gmmWeights'] as List?)?.length ?? 0;
    return build(
      signal: BaselineSignalType.eeg,
      model: 'gmm-arousal',
      modelVersion: '1.0.0',
      featureSchema: 'muse-bandpower-$features',
      parameters: modelState,
      dims: {'features': features, 'clusters': clusters},
      recordedSeconds: recordedSeconds,
      validUntil: validUntil ?? DateTime.now().add(const Duration(days: 365)),
      ownerWallet: ownerWallet,
      createdAt: createdAt,
    );
  }

  /// Recompute a baseline's hash from a candidate parameter set. Used by the
  /// verifier: a consumer re-hashes the parameters it received and checks the
  /// result against the on-chain commitment.
  String hashParameters(Map<String, dynamic> parameters) =>
      _hashing.hashString(canonicalSerialize(parameters));

  /// Language-agnostic canonical serialization. Sorted keys, no whitespace, and
  /// a number rule that MATCHES the Node reference tool
  /// (tools/baseline_anchor/lib_baseline.mjs canonicalSerialize): whole-valued
  /// numbers render without a decimal point (2.0 -> "2", 0.0 -> "0"), so a
  /// baseline hashed in Flutter verifies in a Node.js service and vice versa.
  static String canonicalSerialize(Object? v) {
    if (v == null) return 'null';
    if (v is bool) return v ? 'true' : 'false';
    if (v is num) {
      if (v is int) return v.toString();
      final d = v.toDouble();
      if (!d.isFinite) throw StateError('non-finite number in baseline');
      if (d == d.roundToDouble()) return d.toInt().toString();
      return d.toString();
    }
    if (v is String) return jsonEncode(v);
    if (v is List) {
      return '[${v.map(canonicalSerialize).join(',')}]';
    }
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalSerialize(v[k])}').join(',')}}';
    }
    throw StateError('unserializable type: ${v.runtimeType}');
  }

  /// Keys that must never appear as a payload (array/object) in an on-chain
  /// envelope. Mirrors the Node reference tool's FORBIDDEN_KEYS.
  static const forbiddenPayloadKeys = {
    'gmmMeans', 'gmmCovariances', 'gmmWeights', 'scalerMean', 'scalerScale',
    'means', 'covariances', 'weights', 'features', 'featureVector', 'pcaData',
    'raw', 'rawData', 'samples', 'beats', 'rr', 'rrIntervals', 'mvc',
    'clusterToArousal', 'parameters',
  };

  /// Throw if [envelope] carries anything beyond a commitment + shape metadata.
  /// A defense-in-depth backstop, independent of how the envelope was built.
  static void assertEnvelopeSafe(Map<String, dynamic> envelope) {
    void walk(Object? node, String path) {
      if (node is List) {
        final numeric = node.whereType<num>().length;
        if (numeric > 4) {
          throw StateError(
              'privacy gate: numeric array at $path (len ${node.length}) '
              'looks like raw parameters');
        }
        for (var i = 0; i < node.length; i++) {
          walk(node[i], '$path[$i]');
        }
      } else if (node is Map) {
        node.forEach((k, v) {
          final isPayload = v is List || v is Map;
          if (forbiddenPayloadKeys.contains(k) && isPayload) {
            throw StateError('privacy gate: forbidden payload key "$k" at $path');
          }
          walk(v, '$path.$k');
        });
      }
    }

    walk(envelope, 'envelope');
  }
}
