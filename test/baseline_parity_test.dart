import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthlog/data/baseline/baseline_hashing.dart';
import 'package:healthlog/data/crypto/hashing_service.dart';

/// Cross-language parity guard.
///
/// Asserts that the Dart baseline hasher produces the SAME commitment as the
/// Node reference tool (tools/baseline_anchor) for the shared sample baselines.
/// The Node hashes below are produced by
/// `node anchor_baseline.mjs --baseline samples/<x>.json --dry-run`.
/// If either implementation's canonical serializer drifts, this test fails.
void main() {
  final hashing = BaselineHashing(HashingService());

  // signal sample file -> Node-computed baselineHash
  const nodeHashes = {
    'tools/baseline_anchor/samples/eeg_gmm_arousal.json':
        '509c8630cca738dbd4ade4a08b450c6cd700861136870d30e94a8b19bcfda1ca',
    'tools/baseline_anchor/samples/emg_normalization.json':
        '2b9f99cd12d7e55c6040cbd9577619f3dd10a7fb13ca605b68bfede68a1e4806',
    'tools/baseline_anchor/samples/hrv_resting.json':
        '929e9e779c58c579f9d64b11ef731fe9db9f4f9e94310b087f106bd059147679',
  };

  nodeHashes.forEach((path, nodeHash) {
    test('Dart hash matches Node hash for ${path.split('/').last}', () {
      final doc =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final baseline = doc['baseline'] as Map<String, dynamic>;
      expect(hashing.hashParameters(baseline), nodeHash);
    });
  });

  test('canonicalSerialize renders whole-valued doubles without a decimal', () {
    // The exact rule that unifies Dart and JS number formatting.
    expect(BaselineHashing.canonicalSerialize(0.0), '0');
    expect(BaselineHashing.canonicalSerialize(2.0), '2');
    expect(BaselineHashing.canonicalSerialize(-0.7), '-0.7');
    expect(BaselineHashing.canonicalSerialize(0.42), '0.42');
    expect(BaselineHashing.canonicalSerialize(1031.0), '1031');
    expect(BaselineHashing.canonicalSerialize(600), '600');
    // Key order does not matter.
    expect(
      BaselineHashing.canonicalSerialize({'b': 1, 'a': 2}),
      BaselineHashing.canonicalSerialize({'a': 2, 'b': 1}),
    );
  });
}
