import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../domain/models/solana_models.dart';

class HashingService {
  /// SHA-256 hash of a file's raw bytes.
  Future<String> hashRawFile(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// SHA-256 hash of an arbitrary string.
  String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Stable JSON encoder for crypto-bound payloads.
  ///
  /// Dart preserves map insertion order, but crypto verification should not
  /// depend on how a caller happened to construct a map. This recursively sorts
  /// object keys before JSON encoding.
  String canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

  String hashCanonicalJson(Object? value) => hashString(canonicalJson(value));

  /// Build a SessionManifest from a WearableSession.
  /// Uses session.startedAt as createdAt for deterministic hashing --
  /// the same session fields always produce the same manifest hash.
  SessionManifest createSessionManifest(WearableSession session) {
    return SessionManifest(
      sessionId: session.id,
      ownerWallet: session.ownerWallet,
      deviceSource: session.sourceDevice,
      signalTypes: List.unmodifiable(session.signalTypes),
      rawFileHash: session.rawFileHash ?? '',
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      createdAt: session.createdAt,
    );
  }

  /// Deterministic hash of a manifest using its canonical JSON form.
  String hashManifest(SessionManifest manifest) {
    return hashString(manifest.toCanonicalJson());
  }

  /// Hash of an AI report's summary content for verification.
  String hashAIReport(AIReport report) {
    final payload = {
      'reportId': report.reportId,
      'sessionId': report.sessionId,
      'reportType': report.reportType,
      'inputManifestHash': report.inputManifestHash,
      'permittedDataScope': report.permittedDataScope.name,
      'summaryJson': report.summaryJson,
      'createdAt': report.createdAt.toIso8601String(),
    };
    return hashCanonicalJson(payload);
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) =>
              MapEntry(entry.key.toString(), _canonicalize(entry.value)))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return Map<String, Object?>.fromEntries(entries);
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}
