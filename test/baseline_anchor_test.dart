import 'package:flutter_test/flutter_test.dart';
import 'package:healthlog/data/baseline/baseline_hashing.dart';
import 'package:healthlog/data/baseline/mock_baseline_anchor_service.dart';
import 'package:healthlog/data/crypto/hashing_service.dart';
import 'package:healthlog/domain/models/baseline_models.dart';

/// Privacy + integrity acceptance criteria for on-chain baseline anchoring.
///
/// Core invariant: a baseline's fitted parameters are hashed but NEVER written
/// on-chain. The commitment must bind (tamper is detected) and the memo
/// envelope must carry nothing but a hash + shape metadata.
void main() {
  late HashingService hashing;
  late BaselineHashing baselineHashing;

  // A realistic private EEG baseline (identical shape to GmmModelState).
  final eegParams = <String, dynamic>{
    'featureCols': ['theta', 'alpha', 'beta', 'tbr'],
    'clusterToArousal': {'0': 'low', '1': 'medium', '2': 'high'},
    'scalerMean': [12.41, 9.83, 6.12, 2.07],
    'scalerScale': [3.11, 2.44, 1.63, 0.58],
    'gmmWeights': [0.42, 0.35, 0.23],
    'gmmMeans': [
      [-0.81, 0.62, -0.44, -0.70],
      [0.10, -0.05, 0.08, 0.02],
      [0.79, -0.61, 0.55, 0.83],
    ],
  };

  setUp(() {
    hashing = HashingService();
    baselineHashing = BaselineHashing(hashing);
  });

  WearableBaseline buildEeg() => baselineHashing.build(
        signal: BaselineSignalType.eeg,
        model: 'gmm-arousal',
        modelVersion: '1.0.0',
        featureSchema: 'muse-bandpower-4',
        parameters: eegParams,
        dims: const {'features': 4, 'clusters': 3},
        recordedSeconds: 300,
        validUntil: DateTime(2027, 7, 31),
        ownerWallet: 'OwnerWallet111',
      );

  group('Baseline hashing', () {
    test('is deterministic and key-order independent', () {
      final reordered = <String, dynamic>{
        'gmmWeights': eegParams['gmmWeights'],
        'clusterToArousal': eegParams['clusterToArousal'],
        'featureCols': eegParams['featureCols'],
        'scalerScale': eegParams['scalerScale'],
        'scalerMean': eegParams['scalerMean'],
        'gmmMeans': eegParams['gmmMeans'],
      };
      expect(
        baselineHashing.hashParameters(eegParams),
        baselineHashing.hashParameters(reordered),
      );
    });

    test('changing a single parameter changes the commitment', () {
      final tampered = Map<String, dynamic>.from(eegParams)
        ..['gmmWeights'] = [0.43, 0.34, 0.23];
      expect(
        baselineHashing.hashParameters(eegParams),
        isNot(baselineHashing.hashParameters(tampered)),
      );
    });
  });

  group('On-chain envelope privacy', () {
    test('envelope carries the hash but none of the raw parameters', () {
      final b = buildEeg();
      final manifest = BaselineManifest(
        owner: b.ownerWallet!,
        signal: b.signalType,
        model: b.model,
        modelVersion: b.modelVersion,
        featureSchema: b.featureSchema,
        featureSchemaHash: b.featureSchemaHash,
        baselineHash: b.baselineHash,
        dims: b.dims,
        recordedSeconds: b.recordedSeconds,
        validUntil: b.validUntil,
        ts: b.createdAt,
      );
      final memoText = manifest.toMemoText();

      expect(memoText, contains(b.baselineHash));
      // Not one raw parameter value or key leaks into the memo.
      for (final key in ['gmmMeans', 'gmmWeights', 'scalerMean', 'scalerScale',
        'clusterToArousal', 'featureCols']) {
        expect(memoText.contains('"$key"'), isFalse,
            reason: 'forbidden key "$key" found in on-chain memo');
      }
      expect(memoText.contains('12.41'), isFalse); // a scaler value
      expect(memoText.contains('0.42'), isFalse); // a gmm weight
    });

    test('assertEnvelopeSafe rejects a leaky envelope', () {
      final leaky = {
        'type': 'baseline_commitment',
        'owner': 'x',
        'gmmMeans': [
          [1.0, 2.0, 3.0, 4.0, 5.0],
        ],
      };
      expect(() => BaselineHashing.assertEnvelopeSafe(leaky),
          throwsStateError);
    });

    test('assertEnvelopeSafe accepts a clean envelope', () {
      final clean = buildEeg();
      final env = BaselineManifest(
        owner: clean.ownerWallet!,
        signal: clean.signalType,
        model: clean.model,
        modelVersion: clean.modelVersion,
        featureSchema: clean.featureSchema,
        featureSchemaHash: clean.featureSchemaHash,
        baselineHash: clean.baselineHash,
        dims: clean.dims,
        recordedSeconds: clean.recordedSeconds,
        validUntil: clean.validUntil,
        ts: clean.createdAt,
      ).toEnvelope();
      expect(() => BaselineHashing.assertEnvelopeSafe(env), returnsNormally);
    });
  });

  group('Anchor + verify round trip (mock)', () {
    test('correct parameters verify; tampered parameters fail', () async {
      final service = MockBaselineAnchorService(baselineHashing);
      final b = buildEeg();
      final commitment = await service.anchorBaseline(b);

      final good = await service.verifyBaseline(
        txSignature: commitment.txSignature,
        candidateParameters: eegParams,
        expectedOwner: b.ownerWallet,
      );
      expect(good.allPassed, isTrue);
      expect(good.hashMatches, isTrue);
      expect(good.noRawParameters, isTrue);

      final tampered = Map<String, dynamic>.from(eegParams)
        ..['gmmWeights'] = [0.99, 0.005, 0.005];
      final bad = await service.verifyBaseline(
        txSignature: commitment.txSignature,
        candidateParameters: tampered,
        expectedOwner: b.ownerWallet,
      );
      expect(bad.hashMatches, isFalse);
      expect(bad.allPassed, isFalse);
    });

    test('revoked baseline fails verification', () async {
      final service = MockBaselineAnchorService(baselineHashing);
      final b = buildEeg();
      final commitment = await service.anchorBaseline(b);
      await service.revokeBaseline(baselineId: b.baselineId);

      final result = await service.verifyBaseline(
        txSignature: commitment.txSignature,
        candidateParameters: eegParams,
      );
      expect(result.isBaselineCommitment, isFalse);
      expect(result.allPassed, isFalse);
    });
  });
}
