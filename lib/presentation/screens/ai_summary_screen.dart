import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../providers/solana_providers.dart';

class AISummaryScreen extends ConsumerWidget {
  final String sessionId;
  const AISummaryScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(aiReportsProvider)[sessionId];
    final theme = Theme.of(context);

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Summary')),
        body: const Center(child: Text('No AI summary generated yet.')),
      );
    }

    final summary = report.summaryJson;
    final museDetails =
        summary['muselogDetails'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('AI Summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.solanaPurple.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scope-gated session summary',
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        report.permittedDataScope.displayName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.solanaTeal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(report.disclaimer,
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionTitle(theme, 'Session Overview'),
          _kvRow('Device', summary['deviceSource'] ?? '-'),
          _kvRow('Device Name', summary['deviceName'] ?? '-'),
          _kvRow('Duration', summary['durationFormatted'] ?? '-'),
          _kvRow('Signals',
              (summary['signalTypes'] as List?)?.join(', ') ?? '-'),
          _kvRow('Samples', '${summary['sampleCount'] ?? 0}'),
          _kvRow('Scope', summary['scope'] ?? '-'),
          const SizedBox(height: 16),

          if (museDetails.isNotEmpty) ...[
            _sectionTitle(theme, 'MuseLog Details'),
            if (museDetails['eeg'] != null) ...[
              _kvRow('EEG Channels',
                  (museDetails['eeg']['channels'] as List?)?.join(', ') ?? '-'),
              _kvRow('EEG Sample Rate',
                  '${museDetails['eeg']['sampleRate'] ?? '-'} Hz'),
              if (museDetails['eeg']['signalQuality'] != null)
                _kvRow('Signal Quality', museDetails['eeg']['signalQuality']),
            ],
            if (museDetails['imu'] != null) ...[
              _kvRow('IMU', 'Gyroscope + Accelerometer'),
              _kvRow('Movement', museDetails['imu']['movementContext'] ?? '-'),
            ],
            if (museDetails['bandPower'] != null)
              _kvRow('Band Powers',
                  (museDetails['bandPower']['bands'] as List?)?.join(', ') ?? '-'),
            if (museDetails['fNIRS'] != null)
              _kvRow('fNIRS', 'Present'),
            if (museDetails['ppg'] != null)
              _kvRow('PPG', 'Present'),
            if (museDetails['signalQualitySummary'] != null) ...[
              const SizedBox(height: 8),
              _kvRow('Overall Quality',
                  museDetails['signalQualitySummary']['overallQuality'] ?? '-'),
              _kvRow('Missing Data',
                  museDetails['signalQualitySummary']['missingDataEstimate'] ?? '-'),
              _kvRow('Artifacts',
                  museDetails['signalQualitySummary']['artifactEstimate'] ?? '-'),
            ],
            const SizedBox(height: 16),
          ],

          _sectionTitle(theme, 'Provenance'),
          _hashRow(context, 'Manifest Hash', report.inputManifestHash),
          _hashRow(context, 'Report Hash', report.outputHash),
          _kvRow('Scope', report.permittedDataScope.displayName),
          _kvRow('Verified', report.verifierStatus ? 'Yes' : 'No'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold)),
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(key,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _hashRow(BuildContext context, String label, String hash) {
    final display = hash.length > 20 ? '${hash.substring(0, 20)}...' : hash;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          Expanded(child: Text(display,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          IconButton(
            icon: const Icon(Icons.copy, size: 14),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied')),
              );
            },
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
