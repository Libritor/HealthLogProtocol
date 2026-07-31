import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../data/arousal/model_state_loader.dart';
import '../../data/baseline/baseline_reuse_service.dart';
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
  final Map<String, BaselineReuseResult> _reuse = {};
  final BaselineReuseService _reuseService = BaselineReuseService();
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
      'gmmMeans': [
        [-0.81, 0.62, -0.44, -0.70],
        [0.10, -0.05, 0.08, 0.02],
        [0.79, -0.61, 0.55, 0.83],
      ],
      'gmmCovariances': [
        [[0.55, 0.02, 0.01, 0.00], [0.02, 0.48, 0.00, 0.01], [0.01, 0.00, 0.51, 0.02], [0.00, 0.01, 0.02, 0.44]],
        [[0.61, 0.01, 0.00, 0.02], [0.01, 0.59, 0.01, 0.00], [0.00, 0.01, 0.63, 0.01], [0.02, 0.00, 0.01, 0.57]],
        [[0.49, 0.03, 0.02, 0.01], [0.03, 0.52, 0.01, 0.02], [0.02, 0.01, 0.47, 0.00], [0.01, 0.02, 0.00, 0.53]],
      ],
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

  Future<void> _anchorMyCalibration() async {
    // Read the GmmModelState the calibration flow persisted
    // (arousal_model_state.json) — camelCase, and directly reusable.
    final state = await ModelStateLoader().loadModelStateFromFile();
    if (state == null || state['gmmWeights'] == null) {
      _snack('No saved calibration found — run MuseLog → Calibrate, then return.',
          error: true);
      return;
    }
    final hashing = ref.read(baselineHashingProvider);
    final wallet = ref.read(baselineAnchorServiceProvider).connectedWallet;
    final baseline = hashing.fromModelStateJson(state, ownerWallet: wallet);
    ref.read(baselinesProvider.notifier).add(baseline);
    if (!mounted) return;
    _snack('Loaded your calibrated baseline '
        '(${baseline.dims['features']} features · '
        '${baseline.dims['clusters']} clusters). Tap Anchor to commit it.');
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

  /// Consumer-side reuse: run arousal inference from a verified baseline on a
  /// fresh "elevated arousal" feature sample — no recording, no recalibration.
  void _runReuse(WearableBaseline b) {
    final params = b.parameters;
    if (params == null || params['gmmMeans'] == null) {
      _snack('This baseline has no GMM parameters to run inference with.',
          error: true);
      return;
    }
    try {
      final mean = (params['scalerMean'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final scale = (params['scalerScale'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      // A fresh live sample skewed toward high arousal, in standardized space.
      const z = [0.7, -0.5, 0.5, 0.8];
      final raw = List<double>.generate(
          mean.length, (i) => mean[i] + z[i % z.length] * scale[i]);
      setState(() => _reuse[b.baselineId] = _reuseService.classify(params, raw));
    } catch (e) {
      _snack('Inference failed: $e', error: true);
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
          OutlinedButton.icon(
            onPressed: _busy ? null : _anchorMyCalibration,
            icon: const Icon(Icons.memory, size: 18),
            label: const Text('Add my calibrated EEG baseline'),
          ),
          const SizedBox(height: 10),
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
            if (verification?.allPassed == true &&
                b.signalType == BaselineSignalType.eeg) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _runReuse(b),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Reuse: run arousal inference (no re-record)'),
              ),
              if (_reuse[b.baselineId] != null)
                _reusePanel(theme, _reuse[b.baselineId]!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reusePanel(ThemeData theme, BaselineReuseResult r) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.solanaPurple, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 16, color: AppColors.solanaTeal),
              const SizedBox(width: 8),
              Text('Inference from verified baseline',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Arousal: ${r.arousalLabel.toUpperCase()}  '
              '(index ${r.arousalIndex.toStringAsFixed(2)})',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.solanaTeal)),
          const SizedBox(height: 2),
          Text('Classified a fresh sample with your own baseline — '
              'no recording, no recalibration.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
        ],
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
