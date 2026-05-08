import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../domain/models/solana_models.dart';
import 'wearable_adapter.dart';

class ManualCSVAdapter implements WearableAdapter {
  static const _uuid = Uuid();

  @override
  String get id => 'manual_csv';

  @override
  String get name => 'Manual CSV';

  @override
  List<String> get supportedSignalTypes => const ['Custom'];

  @override
  Future<WearableSession> importSession(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n');

    final rowCount = lines.length > 1 ? lines.length - 1 : 0;
    final fileName = file.uri.pathSegments.last;

    return WearableSession(
      id: _uuid.v4(),
      sourceDevice: DataSourceType.manualCsv,
      sourceAdapter: id,
      signalTypes: const ['Custom'],
      rawFileUri: file.path,
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
      sampleCount: rowCount,
      sessionName: fileName.replaceAll('.csv', ''),
    );
  }
}
