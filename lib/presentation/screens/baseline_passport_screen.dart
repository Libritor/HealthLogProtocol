import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../domain/models/baseline_models.dart';
import '../providers/baseline_providers.dart';

/// The "baseline passport": record a wearable baseline once, anchor its
/// integrity hash on-chain, and let any app verify + reuse it — no re-recording.
class BaselinePassportScreen extends ConsumerStatefulWidget {
  const BaselinePassportScreen({super.key});

  @override
  ConsumerState<BaselinePassportScreen> createState() =>
      _BaselinePassportScreenState();
}

class _BaselinePassportScreenState
    extends ConsumerState<BaselinePassportScreen> {
  final Map<String, BaselineVerification> _verifications = {};
  bool _busy = false;

  /// Demo parameter sets — the private, off-chain calibration payloads. These
  /// mirror tools/baseline_anchor/samples/*.json.
  static final _demoParams = <BaselineSignalType, Map<String, dynamic>>{
    BaselineSignalType.eeg: {
      'featureCols': ['theta', 'alpha', 'beta', 'tbr'],
      'clusterToArousal': {'0': 'low', '1': 'medium', '2': 'high'},
      'scalerMean': [12.41, 9.83, 6.12, 2.07],
      'scalerScale': [3.11, 2.44, 1.63, 0.58],
      'gmmWeights': [0.42, 0.35, 0.23],
    },
    BaselineSignalType.emg: {
      'channels': ['biceps_brachii', 'triceps_brachii'],
      'sampleRateHz': 1000,
      'mvcMicrovolts': [842.3, 611.7],
      'restRmsMicrovolts': [7.4, 6.1],
    },
    BaselineSignalType.hrv: {
      'restingHrBpm': 58.2,
      'sdnnMs': 62.4,
      'rmssdMs': 48.9,
      'lfHfRatio': 1.26,
    },
  };

  Future<void> _loadDemoBaselines() async {
    final hashing = ref.read(baselineHashingProvider);
    final notifier = ref.read(baselinesProvider.notifier);
    final b1 = hashing.build(
      signal: BaselineSignalType.eeg,
      model: 'gmm-arousal',
      modelVersion: '1.0.0',
      featureSchema: 'muse-bandpower-4',
      parameters: _demoParams[BaselineSignalType.eeg]!,
      dims: const {'features': 4, 'clusters': 3},
      recordedSeconds: 300,
      validUntil: DateTime(2027, 7, 31),
    );
    final b2 = hashing.build(
      signal: BaselineSignalType.emg,
      model: 'emg-mvc-normalization',
      modelVersion: '1.0.0',
      featureSchema: 'semg-2ch-rms',
      parameters: _demoParams[BaselineSignalType.emg]!,
      dims: const {'features': 2, 'clusters': 0},
      recordedSeconds: 120,
      validUntil: DateTime(2027, 1, 31),
    );
    final b3 = hashing.build(
      signal: BaselineSignalType.hrv,
      model: 'hrv-resting-norms',
      modelVersion: '1.0.0',
      featureSchema: 'hrv-timedomain-v1',
      parameters: _demoParams[BaselineSignalType.hrv]!,
      dims: const {'features': 8, 'clusters': 0},
      recordedSeconds: 604800,
      validUntil: DateTime(2026, 10, 31),
    );
    notifier
      ..clear()
      ..add(b3)
      ..add(b2)
      ..add(b1);
  }

  Future<void> _anchor(WearableBaseline baseline) async {
    setState(() => _busy = true);
    try {
      final service = ref.read(baselineAnchorServiceProvider);
      await service.connectWallet();
      final commitment = await service.anchorBaseline(baseline);
      ref.read(baselinesProvider.notifier).update(commitment.baseline);
      _snack('Anchored: ${_short(commitment.txSignature)}');
    } catch (e) {
      _snack('Anchor failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(WearableBaseline baseline) async {
    final sig = baseline.onchainTxSignature;
    if (sig == null) {
      _snack('Anchor the baseline first.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final service = ref.read(baselineAnchorServiceProvider);
      // Consumer re-hashes the parameters it holds and checks them on-chain.
      final result = await service.verifyBaseline(
        txSignature: sig,
        candidateParameters: baseline.parameters ?? const {},
        expectedOwner: baseline.ownerWallet,
      );
      setState(() => _verifications[baseline.baselineId] = result);
    } catch (e) {
      _snack('Verify failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.surfaceHigh,
      ),
    );
  }

  String _short(String s) =>
      s.length <= 14 ? s : '${s.substring(0, 8)}…${s.substring(s.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baselines = ref.watch(baselinesProvider);
    final rpc = ref.watch(baselineAnchorServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Baseline Passport')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Your baselines, anchored once',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Record a calibration once. Anchor its integrity hash on-chain. '
            'Any BCI or wearable app verifies and reuses it — no re-recording. '
            'Only the hash and shape metadata go on-chain; the parameters stay '
            'encrypted on your device.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.dns_outlined,
                  size: 16, color: AppColors.onSurfaceMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('RPC: ${rpc.modeLabel}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.onSurfaceMuted)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (baselines.isEmpty)
            FilledButton.icon(
              onPressed: _busy ? null : _loadDemoBaselines,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Load demo baselines (EEG · EMG · HRV)'),
            )
          else
            ...baselines.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _baselineCard(theme, b),
                )),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _baselineCard(ThemeData theme, WearableBaseline b) {
    final verification = _verifications[b.baselineId];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${b.signalType.displayName} · ${b.model}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                _statusChip(b),
              ],
            ),
            const SizedBox(height: 8),
            _kv('Schema', '${b.featureSchema} v${b.modelVersion}'),
            _kv('Shape', b.dims.entries.map((e) => '${e.key}=${e.value}').join(' · ')),
            _kv('Commitment', _short(b.baselineHash)),
            if (b.validUntil != null)
              _kv('Valid until',
                  '${b.validUntil!.toIso8601String().substring(0, 10)}'
                  '${b.isFresh ? '' : '  (stale — recalibrate)'}'),
            if (b.onchainTxSignature != null)
              InkWell(
                onTap: () {
                  final url = ref
                      .read(baselineAnchorServiceProvider)
                      .rpcConfig
                      .explorerTxUrl(b.onchainTxSignature!);
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                },
                child: _kv('Tx', _short(b.onchainTxSignature!),
                    accent: true),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ||
                            b.onchainStatus == BaselineOnchainStatus.anchored
                        ? null
                        : () => _anchor(b),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Anchor'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _verify(b),
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Verify'),
                  ),
                ),
              ],
            ),
            if (verification != null) ...[
              const SizedBox(height: 12),
              _verificationPanel(theme, verification),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verificationPanel(ThemeData theme, BaselineVerification v) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: v.allPassed ? AppColors.success : AppColors.danger,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v.allPassed
                ? 'VERIFIED — safe to load'
                : 'FAILED — do not trust',
            style: theme.textTheme.labelLarge?.copyWith(
              color: v.allPassed ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...v.checks.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(c.value ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: c.value
                            ? AppColors.success
                            : AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.key,
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _statusChip(WearableBaseline b) {
    final anchored = b.onchainStatus == BaselineOnchainStatus.anchored;
    return Chip(
      label: Text(b.onchainStatus.displayName),
      backgroundColor:
          anchored ? const Color(0xFF0F3A2E) : AppColors.surfaceHigh,
      labelStyle: TextStyle(
        color: anchored ? AppColors.success : AppColors.onSurfaceMuted,
        fontSize: 11,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _kv(String k, String v, {bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(k,
                style: const TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(v,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: accent ? AppColors.solanaTeal : AppColors.onSurface,
                )),
          ),
        ],
      ),
    );
  }
}
