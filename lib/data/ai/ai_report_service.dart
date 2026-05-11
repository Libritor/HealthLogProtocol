import 'package:uuid/uuid.dart';
import '../../domain/models/solana_models.dart';
import '../crypto/hashing_service.dart';

/// Generates AI-ready session summaries from wearable data.
///
/// **LLM access rule**: The LLM must never automatically receive raw wearable
/// data. It receives only the scope the user approved (AI summary, derived
/// features, or research metadata). Raw encrypted session access is a future
/// advanced option only.
class AIReportService {
  static const _uuid = Uuid();
  final HashingService _hashingService;

  AIReportService({HashingService? hashingService})
      : _hashingService = hashingService ?? HashingService();

  Future<AIReport> generateSessionSummary({
    required WearableSession session,
    required String manifestHash,
    ConsentScope scope = ConsentScope.aiSummaryOnly,
    String? accessGrantId,
  }) async {
    final summaryJson = await _buildSummary(session, scope);

    final reportId = _uuid.v4();
    final outputHash = _hashingService.hashCanonicalJson(summaryJson);

    return AIReport(
      reportId: reportId,
      sessionId: session.id,
      reportType: 'session_summary',
      inputManifestHash: manifestHash,
      permittedDataScope: scope,
      accessGrantId: accessGrantId,
      outputHash: outputHash,
      summaryJson: summaryJson,
      verifierStatus: true,
      createdAt: DateTime.now(),
    );
  }

  Future<Map<String, dynamic>> _buildSummary(
    WearableSession session,
    ConsentScope scope,
  ) async {
    final summary = <String, dynamic>{
      'sessionId': session.id,
      'deviceSource': session.sourceDevice.displayName,
      'deviceName': session.deviceName ?? 'Unknown',
      'duration': session.duration?.inSeconds ?? 0,
      'durationFormatted': _formatDuration(session.duration),
      'signalTypes': session.signalTypes,
      'sampleCount': session.sampleCount ?? 0,
      'startedAt': session.startedAt.toIso8601String(),
      'endedAt': session.endedAt?.toIso8601String(),
      'scope': scope.displayName,
    };

    if (session.sourceDevice == DataSourceType.muselog) {
      summary['muselogDetails'] = _buildMuseLogDetails(session, scope);
    }

    return summary;
  }

  Map<String, dynamic> _buildMuseLogDetails(
    WearableSession session,
    ConsentScope scope,
  ) {
    final details = <String, dynamic>{
      'deviceType': session.deviceName ?? 'Muse-class device',
    };

    if (session.signalTypes.contains('EEG')) {
      details['eeg'] = {
        'channels': const ['TP9', 'AF7', 'AF8', 'TP10'],
        'sampleRate': 256,
        'present': true,
      };

      if (scope != ConsentScope.researchMetadataOnly) {
        details['eeg']['signalQuality'] = 'Good (synthetic demo data)';
        details['eeg']['featurePlaceholders'] = {
          'thetaBetaRatio': 'Available (requires full analysis)',
          'frontalAlphaAsymmetry': 'Available (requires full analysis)',
        };
      }
    }

    if (session.signalTypes.contains('IMU')) {
      details['imu'] = {
        'gyroscope': true,
        'accelerometer': true,
        'sampleRate': 52,
        'movementContext': 'Low movement (seated, synthetic demo data)',
      };
    }

    if (session.signalTypes.contains('BandPower')) {
      details['bandPower'] = {
        'bands': const ['Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'],
        'channels': const ['TP9', 'AF7', 'AF8', 'TP10'],
        'present': true,
      };
    }

    if (session.signalTypes.contains('fNIRS')) {
      details['fNIRS'] = {
        'present': true,
        'type': 'Near-infrared spectroscopy'
      };
    }

    if (session.signalTypes.contains('PPG')) {
      details['ppg'] = {'present': true, 'type': 'Photoplethysmography'};
    }

    details['signalQualitySummary'] = {
      'overallQuality': 'Good',
      'missingDataEstimate': '< 1%',
      'artifactEstimate': 'Low',
    };

    return details;
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'Unknown';
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${mins}m ${secs}s';
  }
}
