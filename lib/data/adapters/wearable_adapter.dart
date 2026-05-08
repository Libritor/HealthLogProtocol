import 'dart:io';
import '../../domain/models/solana_models.dart';

/// Common interface for importing wearable session data from any source.
abstract class WearableAdapter {
  String get id;
  String get name;
  List<String> get supportedSignalTypes;

  /// Import raw data from a file and produce a WearableSession.
  Future<WearableSession> importSession(File file);
}
