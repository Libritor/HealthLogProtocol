import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../domain/models/solana_models.dart';
import '../providers/solana_providers.dart';
import 'ai_summary_screen.dart';
import 'consent_screen.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  bool _busy = false;

  WearableSession? get _session =>
      ref.read(sessionsProvider.notifier).getById(widget.sessionId);

  Future<void> _doAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _encrypt() => _doAction(() async {
        final session = _session;
        if (session == null || session.rawFileUri == null) return;
        final svc = ref.read(encryptionServiceProvider);
        final result = await svc.encryptFile(File(session.rawFileUri!));
        ref.read(sessionsProvider.notifier).updateSession(
              session.copyWith(
                encryptedFileUri: result.encryptedFile.path,
                encryptionStatus: SessionEncryptionStatus.encrypted,
              ),
            );

        if (!mounted) return;
        final deleteRaw = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Raw File Encrypted'),
            content: const Text(
              'The raw data has been encrypted. '
              'Would you like to delete the raw unencrypted file for privacy, '
              'or keep it for the local demo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep for Local Demo'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete Raw File'),
              ),
            ],
          ),
        );

        if (deleteRaw == true && session.rawFileUri != null) {
          final rawFile = File(session.rawFileUri!);
          if (await rawFile.exists()) {
            await rawFile.delete();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Raw file deleted.')),
              );
            }
          }
        } else if (deleteRaw != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Raw local file still exists. Encrypted copy created.')),
          );
        }
      });

  Future<void> _createManifest() => _doAction(() async {
        final session = _session;
        if (session == null) return;
        final hashSvc = ref.read(hashingServiceProvider);

        String rawHash = session.rawFileHash ?? '';
        if (rawHash.isEmpty && session.rawFileUri != null) {
          rawHash = await hashSvc.hashRawFile(File(session.rawFileUri!));
        }

        var updated = session.copyWith(rawFileHash: rawHash);
        final manifest = hashSvc.createSessionManifest(updated);
        final manifestHash = hashSvc.hashManifest(manifest);
        updated = updated.copyWith(manifestHash: manifestHash);
        ref.read(sessionsProvider.notifier).updateSession(updated);
      });

  Future<void> _commitToSolana() => _doAction(() async {
        final session = _session;
        if (session == null || session.manifestHash == null) return;
        final solana = ref.read(solanaServiceProvider);

        if (solana.connectedWallet == null) {
          final wallet = await solana.connectWallet();
          ref.read(walletAddressProvider.notifier).state = wallet;
        }

        final txSig = await solana.commitSession(
          manifestHash: session.manifestHash!,
          rawFileHash: session.rawFileHash ?? '',
          metadataTags: session.signalTypes,
        );

        ref.read(sessionsProvider.notifier).updateSession(
              session.copyWith(
                ownerWallet: solana.connectedWallet,
                onchainTxSignature: txSig,
                onchainStatus: OnchainStatus.committed,
              ),
            );
      });

  Future<void> _generateAISummary() => _doAction(() async {
        final session = _session;
        if (session == null || session.manifestHash == null) return;

        if (!mounted) return;
        final selectedScope = await showDialog<ConsentScope>(
          context: context,
          builder: (ctx) => _AIScopeDialog(),
        );
        if (selectedScope == null) return;

        ref.read(sessionsProvider.notifier).updateSession(
              session.copyWith(aiSummaryStatus: AISummaryStatus.generating),
            );
        final aiSvc = ref.read(aiReportServiceProvider);
        final report = await aiSvc.generateSessionSummary(
          session: session,
          manifestHash: session.manifestHash!,
          scope: selectedScope,
        );
        ref.read(aiReportsProvider.notifier).addReport(report);
        ref.read(sessionsProvider.notifier).updateSession(
              session.copyWith(aiSummaryStatus: AISummaryStatus.generated),
            );
      });

  Future<void> _openExplorer(String txSig) async {
    final url = Uri.parse(
        'https://explorer.solana.com/tx/$txSig?cluster=devnet');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final session =
        sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(child: Text('Session not found.')),
      );
    }

    final theme = Theme.of(context);
    final report = ref.watch(aiReportsProvider)[session.id];
    final mode = ref.watch(solanaModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Detail'),
        actions: [
          _AppBarModeChip(mode: mode),
          const SizedBox(width: 12),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              children: [
                _statusChips(session, theme),
                const SizedBox(height: 16),
                _infoCard(theme, session),
                const SizedBox(height: 16),
                _hashCard(theme, session),
                if (session.onchainTxSignature != null) ...[
                  const SizedBox(height: 8),
                  _explorerLink(theme, session.onchainTxSignature!),
                ],
                const SizedBox(height: 24),
                _actionButtons(session, report),
              ],
            ),
    );
  }

  Widget _statusChips(WearableSession session, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statusChip(
          icon: Icons.lock_outline,
          label: session.encryptionStatus.displayName,
          color: session.encryptionStatus == SessionEncryptionStatus.encrypted
              ? AppColors.solanaTeal
              : AppColors.onSurfaceDim,
        ),
        _statusChip(
          icon: Icons.cloud_outlined,
          label: session.onchainStatus.displayName,
          color: switch (session.onchainStatus) {
            OnchainStatus.committed => AppColors.info,
            OnchainStatus.shared => AppColors.solanaTeal,
            OnchainStatus.revoked => AppColors.danger,
            _ => AppColors.onSurfaceDim,
          },
        ),
        _statusChip(
          icon: Icons.auto_awesome_outlined,
          label: session.aiSummaryStatus.displayName,
          color: session.aiSummaryStatus == AISummaryStatus.generated
              ? AppColors.solanaPurple
              : AppColors.onSurfaceDim,
        ),
      ],
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(ThemeData theme, WearableSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.sessionName ?? 'Unnamed Session',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _row('Source', session.sourceDevice.displayName),
            _row('Device', session.deviceName ?? '-'),
            _row('Signals', session.signalTypes.join(', ')),
            _row(
                'Duration',
                session.duration != null
                    ? '${session.duration!.inMinutes}m ${session.duration!.inSeconds % 60}s'
                    : '-'),
            _row('Samples', '${session.sampleCount ?? 0}'),
            _row('Started', _fmtTime(session.startedAt)),
            if (session.ownerWallet != null)
              _row('Owner', _truncate(session.ownerWallet!, 16)),
          ],
        ),
      ),
    );
  }

  Widget _hashCard(ThemeData theme, WearableSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provenance',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _copyableRow(
                context, 'File Hash', session.rawFileHash ?? 'Not computed'),
            _copyableRow(context, 'Manifest Hash',
                session.manifestHash ?? 'Not created'),
            _copyableRow(context, 'Tx Signature',
                session.onchainTxSignature ?? 'Not committed'),
          ],
        ),
      ),
    );
  }

  Widget _explorerLink(ThemeData theme, String txSig) {
    return InkWell(
      onTap: () => _openExplorer(txSig),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.solanaTeal.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.open_in_new,
                  size: 14, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'View on Solana Explorer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'devnet • ${_truncate(txSig, 16)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceDim),
          ],
        ),
      ),
    );
  }

  Widget _actionButtons(WearableSession session, AIReport? report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.encryptionStatus != SessionEncryptionStatus.encrypted)
          _actionButton(Icons.lock_outline,
              'Encrypt locally (AES-256-GCM)', _encrypt),
        if (session.manifestHash == null)
          _actionButton(
              Icons.fingerprint, 'Hash + create manifest', _createManifest),
        if (session.manifestHash != null &&
            session.onchainStatus == OnchainStatus.private_)
          _actionButton(Icons.cloud_upload, 'Commit provenance to Solana',
              _commitToSolana),
        if (session.manifestHash != null &&
            session.aiSummaryStatus != AISummaryStatus.generated)
          _actionButton(Icons.auto_awesome,
              'Generate AI summary (scope-gated)', _generateAISummary),
        if (report != null)
          _actionButton(Icons.description, 'View AI summary', () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AISummaryScreen(sessionId: session.id),
              ),
            );
          }),
        if (session.onchainStatus == OnchainStatus.committed ||
            session.onchainStatus == OnchainStatus.shared)
          _actionButton(Icons.key_outlined, 'Issue Data Access Token', () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConsentScreen(sessionId: session.id),
              ),
            );
          }),
      ],
    );
  }

  Widget _actionButton(
      IconData icon, String label, Future<void> Function() onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: _busy ? null : () => onPressed(),
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _copyableRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: Text(_truncate(value, 24),
                style:
                    const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
          if (value.length > 10)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$label copied')));
              },
              tooltip: 'Copy',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  String _truncate(String s, int len) =>
      s.length > len ? '${s.substring(0, len)}...' : s;

  String _fmtTime(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';

  String _p(int n) => n.toString().padLeft(2, '0');
}

class _AppBarModeChip extends StatelessWidget {
  final SolanaMode mode;
  const _AppBarModeChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    final isDevnet = mode == SolanaMode.devnetMemo;
    final color = isDevnet ? AppColors.solanaTeal : AppColors.onSurfaceDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        isDevnet ? 'Devnet' : 'Mock',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AIScopeDialog extends StatefulWidget {
  @override
  State<_AIScopeDialog> createState() => _AIScopeDialogState();
}

class _AIScopeDialogState extends State<_AIScopeDialog> {
  ConsentScope _selected = ConsentScope.aiSummaryOnly;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve AI Data Scope'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HealthLog will generate an AI summary using the '
            'approved data scope below. Raw data is never shared.',
          ),
          const SizedBox(height: 16),
          ...ConsentScope.values
              .where((s) => s != ConsentScope.rawEncryptedSession)
              .map((scope) => RadioListTile<ConsentScope>(
                    title: Text(scope.displayName),
                    value: scope,
                    groupValue: _selected,
                    dense: true,
                    onChanged: (v) => setState(() => _selected = v!),
                  )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Generate Summary'),
        ),
      ],
    );
  }
}
