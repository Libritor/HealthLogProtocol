import 'dart:convert';

// --- Enums ---

enum DataSourceType {
  muselog,
  oura,
  whoop,
  raybanMeta,
  manualCsv,
  demo;

  String get displayName {
    switch (this) {
      case DataSourceType.muselog:
        return 'MuseLog';
      case DataSourceType.oura:
        return 'Oura';
      case DataSourceType.whoop:
        return 'Whoop';
      case DataSourceType.raybanMeta:
        return 'Ray-Ban Meta';
      case DataSourceType.manualCsv:
        return 'Manual CSV';
      case DataSourceType.demo:
        return 'Demo';
    }
  }
}

enum SessionEncryptionStatus {
  unencrypted,
  encrypting,
  encrypted,
  failed;

  String get displayName {
    switch (this) {
      case SessionEncryptionStatus.unencrypted:
        return 'Unencrypted';
      case SessionEncryptionStatus.encrypting:
        return 'Encrypting...';
      case SessionEncryptionStatus.encrypted:
        return 'Encrypted';
      case SessionEncryptionStatus.failed:
        return 'Encryption Failed';
    }
  }
}

enum OnchainStatus {
  private_,
  committing,
  committed,
  shared,
  revoked;

  String get displayName {
    switch (this) {
      case OnchainStatus.private_:
        return 'Private';
      case OnchainStatus.committing:
        return 'Committing...';
      case OnchainStatus.committed:
        return 'Committed';
      case OnchainStatus.shared:
        return 'Shared';
      case OnchainStatus.revoked:
        return 'Revoked';
    }
  }
}

enum AISummaryStatus {
  none,
  generating,
  generated,
  failed;

  String get displayName {
    switch (this) {
      case AISummaryStatus.none:
        return 'Not Generated';
      case AISummaryStatus.generating:
        return 'Generating...';
      case AISummaryStatus.generated:
        return 'Generated';
      case AISummaryStatus.failed:
        return 'Failed';
    }
  }
}

/// Privacy-first ordering: AI summary is the default demo scope.
enum ConsentScope {
  aiSummaryOnly,
  derivedFeaturesOnly,
  researchMetadataOnly,
  rawEncryptedSession;

  String get displayName {
    switch (this) {
      case ConsentScope.aiSummaryOnly:
        return 'AI Summary Only';
      case ConsentScope.derivedFeaturesOnly:
        return 'Derived Features Only';
      case ConsentScope.researchMetadataOnly:
        return 'Research Metadata Only';
      case ConsentScope.rawEncryptedSession:
        return 'Raw Encrypted Session (Advanced)';
    }
  }
}

enum ConsentPurpose {
  aiAnalysis,
  research,
  rehabilitation,
  personalHealth;

  String get displayName {
    switch (this) {
      case ConsentPurpose.aiAnalysis:
        return 'AI Analysis';
      case ConsentPurpose.research:
        return 'Research';
      case ConsentPurpose.rehabilitation:
        return 'Rehabilitation Support';
      case ConsentPurpose.personalHealth:
        return 'Personal Health Tracking';
    }
  }
}

enum TokenStatus {
  active,
  expired,
  revoked;

  String get displayName {
    switch (this) {
      case TokenStatus.active:
        return 'Active';
      case TokenStatus.expired:
        return 'Expired';
      case TokenStatus.revoked:
        return 'Revoked';
    }
  }
}

enum SolanaMode {
  mock,
  devnetMemo,
  anchor;

  String get displayName {
    switch (this) {
      case SolanaMode.mock:
        return 'Mock Mode';
      case SolanaMode.devnetMemo:
        return 'Devnet (Memo)';
      case SolanaMode.anchor:
        return 'Devnet (Anchor)';
    }
  }
}

// --- Data Models ---

class WearableSession {
  final String id;
  final String? ownerWallet;
  final DataSourceType sourceDevice;
  final String sourceAdapter;
  final List<String> signalTypes;
  /// Local-only. Must never be written onchain, exposed in public logs,
  /// or included in public demo exports.
  final String? rawFileUri;
  final String? encryptedFileUri;
  final String? rawFileHash;
  final String? manifestHash;
  final String? sessionName;
  final SessionEncryptionStatus encryptionStatus;
  final OnchainStatus onchainStatus;
  final AISummaryStatus aiSummaryStatus;
  final String? onchainTxSignature;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final int? sampleCount;
  final String? deviceName;

  const WearableSession({
    required this.id,
    this.ownerWallet,
    required this.sourceDevice,
    required this.sourceAdapter,
    required this.signalTypes,
    this.rawFileUri,
    this.encryptedFileUri,
    this.rawFileHash,
    this.manifestHash,
    this.sessionName,
    this.encryptionStatus = SessionEncryptionStatus.unencrypted,
    this.onchainStatus = OnchainStatus.private_,
    this.aiSummaryStatus = AISummaryStatus.none,
    this.onchainTxSignature,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
    this.sampleCount,
    this.deviceName,
  });

  Duration? get duration => endedAt?.difference(startedAt);

  WearableSession copyWith({
    String? ownerWallet,
    String? rawFileUri,
    String? encryptedFileUri,
    String? rawFileHash,
    String? manifestHash,
    String? sessionName,
    SessionEncryptionStatus? encryptionStatus,
    OnchainStatus? onchainStatus,
    AISummaryStatus? aiSummaryStatus,
    String? onchainTxSignature,
    DateTime? endedAt,
    int? sampleCount,
    String? deviceName,
  }) {
    return WearableSession(
      id: id,
      ownerWallet: ownerWallet ?? this.ownerWallet,
      sourceDevice: sourceDevice,
      sourceAdapter: sourceAdapter,
      signalTypes: signalTypes,
      rawFileUri: rawFileUri ?? this.rawFileUri,
      encryptedFileUri: encryptedFileUri ?? this.encryptedFileUri,
      rawFileHash: rawFileHash ?? this.rawFileHash,
      manifestHash: manifestHash ?? this.manifestHash,
      sessionName: sessionName ?? this.sessionName,
      encryptionStatus: encryptionStatus ?? this.encryptionStatus,
      onchainStatus: onchainStatus ?? this.onchainStatus,
      aiSummaryStatus: aiSummaryStatus ?? this.aiSummaryStatus,
      onchainTxSignature: onchainTxSignature ?? this.onchainTxSignature,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt,
      sampleCount: sampleCount ?? this.sampleCount,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerWallet': ownerWallet,
        'sourceDevice': sourceDevice.name,
        'sourceAdapter': sourceAdapter,
        'signalTypes': signalTypes,
        'rawFileHash': rawFileHash,
        'manifestHash': manifestHash,
        'sessionName': sessionName,
        'encryptionStatus': encryptionStatus.name,
        'onchainStatus': onchainStatus.name,
        'aiSummaryStatus': aiSummaryStatus.name,
        'onchainTxSignature': onchainTxSignature,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'sampleCount': sampleCount,
        'deviceName': deviceName,
      };
}

class SessionManifest {
  final String sessionId;
  final String? ownerWallet;
  final DataSourceType deviceSource;
  final List<String> signalTypes;
  final String rawFileHash;
  final String normalizedSchemaVersion;
  final String? featureSummaryHash;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  const SessionManifest({
    required this.sessionId,
    this.ownerWallet,
    required this.deviceSource,
    required this.signalTypes,
    required this.rawFileHash,
    this.normalizedSchemaVersion = '1.0.0',
    this.featureSummaryHash,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'ownerWallet': ownerWallet,
        'deviceSource': deviceSource.name,
        'signalTypes': signalTypes,
        'rawFileHash': rawFileHash,
        'normalizedSchemaVersion': normalizedSchemaVersion,
        'featureSummaryHash': featureSummaryHash,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  String toCanonicalJson() {
    final map = toJson();
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return jsonEncode(sorted);
  }
}

class ConsentGrant {
  final String grantId;
  final String sessionId;
  final String ownerWallet;
  final String recipientWallet;
  final ConsentScope scope;
  final ConsentPurpose purpose;
  final DateTime expiresAt;
  final bool revoked;
  final String? onchainTxSignature;
  final DateTime createdAt;
  final DateTime? revokedAt;

  const ConsentGrant({
    required this.grantId,
    required this.sessionId,
    required this.ownerWallet,
    required this.recipientWallet,
    required this.scope,
    required this.purpose,
    required this.expiresAt,
    this.revoked = false,
    this.onchainTxSignature,
    required this.createdAt,
    this.revokedAt,
  });

  bool get isActive => !revoked && DateTime.now().isBefore(expiresAt);

  bool get isExpired => !revoked && DateTime.now().isAfter(expiresAt);

  ConsentGrant copyWith({
    bool? revoked,
    String? onchainTxSignature,
    DateTime? revokedAt,
  }) {
    return ConsentGrant(
      grantId: grantId,
      sessionId: sessionId,
      ownerWallet: ownerWallet,
      recipientWallet: recipientWallet,
      scope: scope,
      purpose: purpose,
      expiresAt: expiresAt,
      revoked: revoked ?? this.revoked,
      onchainTxSignature: onchainTxSignature ?? this.onchainTxSignature,
      createdAt: createdAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'grantId': grantId,
        'sessionId': sessionId,
        'ownerWallet': ownerWallet,
        'recipientWallet': recipientWallet,
        'scope': scope.name,
        'purpose': purpose.name,
        'expiresAt': expiresAt.toIso8601String(),
        'revoked': revoked,
        'onchainTxSignature': onchainTxSignature,
        'createdAt': createdAt.toIso8601String(),
        'revokedAt': revokedAt?.toIso8601String(),
      };
}

class AccessLog {
  final String accessId;
  final String grantId;
  final String sessionId;
  final String recipientWallet;
  final DateTime accessedAt;
  final String accessType;
  final bool verifiedOnchain;
  final String? notes;

  const AccessLog({
    required this.accessId,
    required this.grantId,
    required this.sessionId,
    required this.recipientWallet,
    required this.accessedAt,
    required this.accessType,
    this.verifiedOnchain = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'accessId': accessId,
        'grantId': grantId,
        'sessionId': sessionId,
        'recipientWallet': recipientWallet,
        'accessedAt': accessedAt.toIso8601String(),
        'accessType': accessType,
        'verifiedOnchain': verifiedOnchain,
        'notes': notes,
      };
}

class AIReport {
  final String reportId;
  final String sessionId;
  final String reportType;
  final String inputManifestHash;
  final ConsentScope permittedDataScope;
  final String? accessGrantId;
  final String outputHash;
  final Map<String, dynamic> summaryJson;
  final bool verifierStatus;
  final String disclaimer;
  final DateTime createdAt;

  static const String defaultDisclaimer =
      'This is a research and wellness data summary, not a medical diagnosis '
      'or medical advice.';

  const AIReport({
    required this.reportId,
    required this.sessionId,
    required this.reportType,
    required this.inputManifestHash,
    required this.permittedDataScope,
    this.accessGrantId,
    required this.outputHash,
    required this.summaryJson,
    this.verifierStatus = false,
    this.disclaimer = defaultDisclaimer,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'sessionId': sessionId,
        'reportType': reportType,
        'inputManifestHash': inputManifestHash,
        'permittedDataScope': permittedDataScope.name,
        'accessGrantId': accessGrantId,
        'outputHash': outputHash,
        'summaryJson': summaryJson,
        'verifierStatus': verifierStatus,
        'disclaimer': disclaimer,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Represents permission to access a specific data scope -- not the data
/// itself. Preferably non-transferable for health/privacy reasons.
class DataAccessToken {
  final String tokenId;
  final String grantId;
  final String sessionId;
  final String recipientWallet;
  final ConsentScope scope;
  final String manifestHash;
  final DateTime expiresAt;
  final bool revoked;
  final DateTime issuedAt;
  final DateTime? revokedAt;

  const DataAccessToken({
    required this.tokenId,
    required this.grantId,
    required this.sessionId,
    required this.recipientWallet,
    required this.scope,
    required this.manifestHash,
    required this.expiresAt,
    this.revoked = false,
    required this.issuedAt,
    this.revokedAt,
  });

  TokenStatus get status {
    if (revoked) return TokenStatus.revoked;
    if (DateTime.now().isAfter(expiresAt)) return TokenStatus.expired;
    return TokenStatus.active;
  }

  DataAccessToken copyWith({bool? revoked, DateTime? revokedAt}) {
    return DataAccessToken(
      tokenId: tokenId,
      grantId: grantId,
      sessionId: sessionId,
      recipientWallet: recipientWallet,
      scope: scope,
      manifestHash: manifestHash,
      expiresAt: expiresAt,
      revoked: revoked ?? this.revoked,
      issuedAt: issuedAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'grantId': grantId,
        'sessionId': sessionId,
        'recipientWallet': recipientWallet,
        'scope': scope.name,
        'manifestHash': manifestHash,
        'expiresAt': expiresAt.toIso8601String(),
        'revoked': revoked,
        'issuedAt': issuedAt.toIso8601String(),
        'revokedAt': revokedAt?.toIso8601String(),
      };
}

/// Result of a grant verification check.
class GrantVerification {
  final bool manifestHashMatch;
  final bool walletSignatureValid;
  final bool grantActive;
  final bool tokenActive;
  final bool aiReportHashMatch;
  final bool scopeMatch;
  final bool rawDataNotExposed;
  final String? errorMessage;

  const GrantVerification({
    required this.manifestHashMatch,
    required this.walletSignatureValid,
    required this.grantActive,
    required this.tokenActive,
    required this.aiReportHashMatch,
    required this.scopeMatch,
    required this.rawDataNotExposed,
    this.errorMessage,
  });

  bool get allPassed =>
      manifestHashMatch &&
      walletSignatureValid &&
      grantActive &&
      tokenActive &&
      aiReportHashMatch &&
      scopeMatch &&
      rawDataNotExposed;

  List<VerificationCheckResult> get checks => [
        VerificationCheckResult(
          'Manifest hash matches onchain commitment',
          manifestHashMatch,
        ),
        VerificationCheckResult(
          'Wallet signature valid',
          walletSignatureValid,
        ),
        VerificationCheckResult(
          'Grant is active (not revoked/expired)',
          grantActive,
        ),
        VerificationCheckResult(
          'Access token is active',
          tokenActive,
        ),
        VerificationCheckResult(
          'AI report hash matches session',
          aiReportHashMatch,
        ),
        VerificationCheckResult(
          'Permitted scope matches accessed scope',
          scopeMatch,
        ),
        VerificationCheckResult(
          'Raw data was not exposed',
          rawDataNotExposed,
        ),
      ];
}

class VerificationCheckResult {
  final String label;
  final bool passed;

  const VerificationCheckResult(this.label, this.passed);
}
