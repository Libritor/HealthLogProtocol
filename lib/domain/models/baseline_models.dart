import 'dart:convert';

/// The physiological signal a baseline calibrates against.
enum BaselineSignalType {
  eeg,
  emg,
  hrv,
  eda,
  ppg,
  imu;

  /// Short on-chain tag (must match the Node reference tool: "eeg", "emg"...).
  String get tag => name;

  String get displayName {
    switch (this) {
      case BaselineSignalType.eeg:
        return 'EEG (brain)';
      case BaselineSignalType.emg:
        return 'EMG (muscle)';
      case BaselineSignalType.hrv:
        return 'HRV (heart)';
      case BaselineSignalType.eda:
        return 'EDA (skin)';
      case BaselineSignalType.ppg:
        return 'PPG (pulse)';
      case BaselineSignalType.imu:
        return 'IMU (motion)';
    }
  }

  static BaselineSignalType fromTag(String tag) =>
      BaselineSignalType.values.firstWhere((e) => e.name == tag,
          orElse: () => BaselineSignalType.eeg);
}

/// What a consumer app is allowed to pull when granted access to a baseline.
///
/// Kept separate from [ConsentScope] (session scopes) so the two consent
/// surfaces evolve independently. Ordered privacy-first.
enum BaselineAccessScope {
  /// Only the non-identifying descriptor (signal, model, dims, validUntil).
  metadataOnly,

  /// The feature-schema spec so a consumer can align its feature extractor,
  /// but not the fitted parameters.
  featureSchemaOnly,

  /// The full baseline parameters (GMM state / MVC levels / HRV norms) so the
  /// consumer can run inference without re-recording. The sensitive scope.
  baselineParameters;

  String get displayName {
    switch (this) {
      case BaselineAccessScope.metadataOnly:
        return 'Metadata Only';
      case BaselineAccessScope.featureSchemaOnly:
        return 'Feature Schema Only';
      case BaselineAccessScope.baselineParameters:
        return 'Full Baseline Parameters';
    }
  }
}

enum BaselineOnchainStatus {
  local,
  anchoring,
  anchored,
  revoked;

  String get displayName {
    switch (this) {
      case BaselineOnchainStatus.local:
        return 'Local only';
      case BaselineOnchainStatus.anchoring:
        return 'Anchoring...';
      case BaselineOnchainStatus.anchored:
        return 'Anchored';
      case BaselineOnchainStatus.revoked:
        return 'Revoked';
    }
  }
}

/// A portable, owner-controlled calibration profile.
///
/// The fitted [parameters] (GMM state, MVC levels, HRV norms) are the private,
/// off-chain payload — the thing that lets a user skip re-recording. Only
/// [baselineHash] (a SHA-256 commitment) and non-identifying shape metadata are
/// ever anchored on-chain.
class WearableBaseline {
  final String baselineId;
  final String? ownerWallet;
  final BaselineSignalType signalType;

  /// Model family, e.g. "gmm-arousal", "emg-mvc-normalization".
  final String model;
  final String modelVersion;

  /// Feature-schema id string (e.g. "muse-bandpower-4"). NOT the raw features.
  final String featureSchema;

  /// SHA-256 over the canonical [parameters]. The on-chain commitment.
  final String baselineHash;

  /// SHA-256 over the feature-schema spec, so consumers can confirm alignment.
  final String? featureSchemaHash;

  /// Shape-only metadata, e.g. {'features': 4, 'clusters': 3}. No values.
  final Map<String, int> dims;

  /// How long the calibration recording was (context, not identifying).
  final int? recordedSeconds;

  /// Recalibration horizon. HRV drifts fast; EEG montage baselines slower.
  final DateTime? validUntil;

  final DateTime createdAt;
  final bool revoked;
  final BaselineOnchainStatus onchainStatus;
  final String? onchainTxSignature;

  /// PRIVATE, local-only. The fitted parameters. Must never be written on-chain,
  /// exposed in public logs, or included in a public export.
  final Map<String, dynamic>? parameters;

  const WearableBaseline({
    required this.baselineId,
    this.ownerWallet,
    required this.signalType,
    required this.model,
    required this.modelVersion,
    required this.featureSchema,
    required this.baselineHash,
    this.featureSchemaHash,
    this.dims = const {},
    this.recordedSeconds,
    this.validUntil,
    required this.createdAt,
    this.revoked = false,
    this.onchainStatus = BaselineOnchainStatus.local,
    this.onchainTxSignature,
    this.parameters,
  });

  bool get isFresh =>
      validUntil == null || DateTime.now().isBefore(validUntil!);

  WearableBaseline copyWith({
    String? ownerWallet,
    bool? revoked,
    BaselineOnchainStatus? onchainStatus,
    String? onchainTxSignature,
  }) {
    return WearableBaseline(
      baselineId: baselineId,
      ownerWallet: ownerWallet ?? this.ownerWallet,
      signalType: signalType,
      model: model,
      modelVersion: modelVersion,
      featureSchema: featureSchema,
      baselineHash: baselineHash,
      featureSchemaHash: featureSchemaHash,
      dims: dims,
      recordedSeconds: recordedSeconds,
      validUntil: validUntil,
      createdAt: createdAt,
      revoked: revoked ?? this.revoked,
      onchainStatus: onchainStatus ?? this.onchainStatus,
      onchainTxSignature: onchainTxSignature ?? this.onchainTxSignature,
      parameters: parameters,
    );
  }

  /// Local metadata (safe to persist/display) — excludes [parameters].
  Map<String, dynamic> toMetadataJson() => {
        'baselineId': baselineId,
        'ownerWallet': ownerWallet,
        'signal': signalType.tag,
        'model': model,
        'modelVersion': modelVersion,
        'featureSchema': featureSchema,
        'baselineHash': baselineHash,
        'featureSchemaHash': featureSchemaHash,
        'dims': dims,
        'recordedSeconds': recordedSeconds,
        'validUntil': validUntil?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'revoked': revoked,
        'onchainStatus': onchainStatus.name,
        'onchainTxSignature': onchainTxSignature,
      };
}

/// The exact, privacy-safe envelope written to the chain. Byte-compatible with
/// the Node reference tool (tools/baseline_anchor/lib_baseline.mjs).
class BaselineManifest {
  final String owner;
  final BaselineSignalType signal;
  final String model;
  final String modelVersion;
  final String featureSchema;
  final String? featureSchemaHash;
  final String baselineHash;
  final Map<String, int> dims;
  final int? recordedSeconds;
  final DateTime? validUntil;
  final DateTime ts;

  const BaselineManifest({
    required this.owner,
    required this.signal,
    required this.model,
    required this.modelVersion,
    required this.featureSchema,
    this.featureSchemaHash,
    required this.baselineHash,
    this.dims = const {},
    this.recordedSeconds,
    this.validUntil,
    required this.ts,
  });

  /// The on-chain envelope. Order of assembly does not matter — the memo text
  /// is produced from this map and hashing is canonicalized elsewhere.
  Map<String, dynamic> toEnvelope() => {
        'type': 'baseline_commitment',
        'v': 1,
        'owner': owner,
        'signal': signal.tag,
        'model': model,
        'modelVersion': modelVersion,
        'featureSchema': featureSchema,
        'featureSchemaHash': featureSchemaHash,
        'baselineHash': baselineHash,
        'dims': dims.isEmpty ? null : dims,
        'recordedSeconds': recordedSeconds,
        'validUntil': validUntil?.toIso8601String(),
        'ts': ts.toIso8601String(),
      };

  String toMemoText() => jsonEncode(toEnvelope());
}

/// Result of anchoring a baseline on-chain.
class BaselineCommitment {
  final WearableBaseline baseline;
  final String txSignature;
  final String explorerUrl;

  const BaselineCommitment({
    required this.baseline,
    required this.txSignature,
    required this.explorerUrl,
  });
}

/// Consumer-side verification result (mirrors verify_baseline.mjs checks).
class BaselineVerification {
  final bool foundOnchain;
  final bool isBaselineCommitment;
  final bool hashMatches;
  final bool ownerMatches;
  final bool withinHorizon;
  final bool noRawParameters;
  final String? errorMessage;

  const BaselineVerification({
    required this.foundOnchain,
    required this.isBaselineCommitment,
    required this.hashMatches,
    required this.ownerMatches,
    required this.withinHorizon,
    required this.noRawParameters,
    this.errorMessage,
  });

  bool get allPassed =>
      foundOnchain &&
      isBaselineCommitment &&
      hashMatches &&
      ownerMatches &&
      withinHorizon &&
      noRawParameters;

  List<MapEntry<String, bool>> get checks => [
        MapEntry('Transaction found on-chain', foundOnchain),
        MapEntry('Envelope is a baseline commitment', isBaselineCommitment),
        MapEntry('Baseline hash matches on-chain commitment', hashMatches),
        MapEntry('Owner wallet matches', ownerMatches),
        MapEntry('Within recalibration horizon', withinHorizon),
        MapEntry('No raw parameters on-chain', noRawParameters),
      ];
}
