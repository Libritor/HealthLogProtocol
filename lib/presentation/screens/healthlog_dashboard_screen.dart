import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../data/adapters/muselog_adapter.dart';
import '../../domain/models/solana_models.dart';
import '../providers/solana_providers.dart';
import 'about_screen.dart';
import 'muselog_source_screen.dart';
import 'session_detail_screen.dart';
import 'verifier_screen.dart';

class HealthLogDashboardScreen extends ConsumerStatefulWidget {
  const HealthLogDashboardScreen({super.key});

  @override
  ConsumerState<HealthLogDashboardScreen> createState() =>
      _HealthLogDashboardScreenState();
}

class _HealthLogDashboardScreenState
    extends ConsumerState<HealthLogDashboardScreen> {
  int _navIndex = 0;
  bool _loading = false;

  Future<void> _loadDemoData() async {
    setState(() => _loading = true);
    try {
      final demoSvc = ref.read(demoDataServiceProvider);
      final wallet = ref.read(solanaServiceProvider).connectedWallet;
      final bundle = await demoSvc.loadDemoData(ownerWallet: wallet);
      ref.read(sessionsProvider.notifier).addSession(bundle.session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo MuseLog session loaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _loading = true);
    try {
      final adapter = MuseLogAdapter();
      final session = await adapter.importSession(File(path));
      ref.read(sessionsProvider.notifier).addSession(session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MuseLog session imported.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showComingSoonSnackBar(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name is on the HealthLog Protocol roadmap. '
          'MuseLog is the first active adapter.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _toggleSolanaMode() async {
    final current = ref.read(solanaModeProvider);
    final next = current == SolanaMode.mock
        ? SolanaMode.devnetMemo
        : SolanaMode.mock;
    ref.read(solanaModeProvider.notifier).state = next;
    ref.read(solanaServiceProvider.notifier).switchMode(next);
    ref.read(walletAddressProvider.notifier).state = null;

    // Auto-connect so the persisted devnet wallet appears immediately.
    try {
      final wallet = await ref.read(solanaServiceProvider).connectWallet();
      if (mounted) {
        ref.read(walletAddressProvider.notifier).state = wallet;
      }
    } catch (_) {
      // Network may be unavailable; address will appear after first action.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to ${next.displayName}')),
    );
  }

  Future<void> _openExplorerForWallet(String wallet) async {
    final mode = ref.read(solanaModeProvider);
    if (mode != SolanaMode.devnetMemo) return;
    final url = Uri.parse(
        'https://explorer.solana.com/address/$wallet?cluster=devnet');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboardBody(),
      const VerifierScreen(),
      const AboutScreen(),
    ];

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pages[_navIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Verify'),
          NavigationDestination(
              icon: Icon(Icons.info_outline),
              selectedIcon: Icon(Icons.info),
              label: 'About'),
        ],
      ),
    );
  }

  Widget _dashboardBody() {
    final theme = Theme.of(context);
    final sessions = ref.watch(sessionsProvider);
    final reports = ref.watch(aiReportsProvider);
    final wallet = ref.watch(walletAddressProvider);
    final mode = ref.watch(solanaModeProvider);
    final stepIndex = _currentDemoStepIndex(sessions, reports);

    return CustomScrollView(
      slivers: [
        SliverAppBar.medium(
          pinned: false,
          floating: true,
          title: ShaderMask(
            shaderCallback: (rect) =>
                AppColors.brandGradient.createShader(rect),
            child: const Text(
              'HealthLog Protocol',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          actions: [
            _ModeChip(mode: mode, onTap: () { _toggleSolanaMode(); }),
            const SizedBox(width: 12),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Your wearable data. Your consent. On Solana.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
                height: 1.4,
              ),
            ),
          ),
        ),

        if (wallet != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _WalletCard(
                wallet: wallet,
                mode: mode,
                onTap: () { _openExplorerForWallet(wallet); },
              ),
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _DemoFlowCard(activeStep: stepIndex),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Text('Data Sources',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.solanaTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'MuseLog active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.solanaTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _wearableSourceCard(
                  theme,
                  icon: Icons.psychology,
                  title: 'MuseLog Brain Sensing',
                  subtitle: 'EEG + IMU sessions from Muse-class devices',
                  active: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MuseLogSourceScreen()),
                  ),
                ),
                _wearableSourceCard(
                  theme,
                  icon: Icons.upload_file,
                  title: 'Manual CSV Import',
                  subtitle: 'Bring any wearable CSV into the protocol',
                  active: true,
                  onTap: _importCsv,
                ),
                _AdaptersComingSoonStrip(onTap: _showComingSoonSnackBar),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FilledButton.icon(
              onPressed: _loadDemoData,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Load Demo Session'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.solanaPurple,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Sessions',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        if (sessions.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _EmptySessionsCard(),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: _sessionTile(sessions[i], theme),
              ),
              childCount: sessions.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(child: _SolanaFooter()),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  /// Drives the gradient highlight on the Demo Flow card.
  /// Steps: Import(0) Encrypt(1) Hash(2) Commit(3) Summarize(4) Grant(5) Verify(6) Revoke(7)
  int _currentDemoStepIndex(
      List<WearableSession> sessions, Map<String, AIReport> reports) {
    if (sessions.isEmpty) return 0;
    final latest = sessions.first;
    if (latest.encryptionStatus != SessionEncryptionStatus.encrypted) return 1;
    if (latest.manifestHash == null) return 2;
    if (latest.onchainStatus == OnchainStatus.private_ ||
        latest.onchainStatus == OnchainStatus.committing) return 3;
    if (latest.aiSummaryStatus != AISummaryStatus.generated) return 4;
    if (latest.onchainStatus == OnchainStatus.committed) return 5;
    if (latest.onchainStatus == OnchainStatus.shared) return 6;
    if (latest.onchainStatus == OnchainStatus.revoked) return 7;
    return 0;
  }

  Widget _wearableSourceCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.solanaPurple.withValues(alpha: 0.16)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 20,
                    color: active
                        ? AppColors.solanaPurple
                        : AppColors.onSurfaceDim),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.onSurfaceDim),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionTile(WearableSession session, ThemeData theme) {
    final statusColor = switch (session.onchainStatus) {
      OnchainStatus.committed => AppColors.info,
      OnchainStatus.shared => AppColors.solanaTeal,
      OnchainStatus.revoked => AppColors.danger,
      _ => AppColors.onSurfaceDim,
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(sessionId: session.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.solanaPurple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: AppColors.solanaPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.sessionName ?? session.id,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${session.sourceDevice.displayName} • '
                      '${session.signalTypes.join(", ")}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  session.onchainStatus.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final SolanaMode mode;
  final VoidCallback onTap;

  const _ModeChip({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDevnet = mode == SolanaMode.devnetMemo;
    final color = isDevnet ? AppColors.solanaTeal : AppColors.onSurfaceDim;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isDevnet ? 'Devnet' : 'Mock',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String wallet;
  final SolanaMode mode;
  final VoidCallback onTap;

  const _WalletCard({
    required this.wallet,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortAddress =
        '${wallet.substring(0, 6)}…${wallet.substring(wallet.length - 4)}';

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Connected wallet',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                            letterSpacing: 0.4)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: mode == SolanaMode.devnetMemo
                            ? AppColors.solanaTeal.withValues(alpha: 0.16)
                            : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mode == SolanaMode.devnetMemo ? 'DEVNET' : 'MOCK',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  shortAddress,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy address',
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: wallet));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet address copied')),
              );
            },
          ),
          if (mode == SolanaMode.devnetMemo)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'View on Solana Explorer',
              icon: const Icon(Icons.open_in_new, size: 16),
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}

class _DemoFlowCard extends StatelessWidget {
  final int activeStep;
  const _DemoFlowCard({required this.activeStep});

  static const _steps = [
    'Import',
    'Encrypt',
    'Hash',
    'Commit',
    'Summarize',
    'Grant',
    'Verify',
    'Revoke',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined,
                  size: 16, color: AppColors.solanaPurple),
              const SizedBox(width: 8),
              Text('Demo Flow',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(
                'runs end-to-end on devnet',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                _StepPill(
                  label: _steps[i],
                  state: i < activeStep
                      ? _StepState.done
                      : i == activeStep
                          ? _StepState.active
                          : _StepState.pending,
                ),
                if (i < _steps.length - 1)
                  const Icon(Icons.chevron_right,
                      size: 14, color: AppColors.onSurfaceDim),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepPill extends StatelessWidget {
  final String label;
  final _StepState state;
  const _StepPill({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.active:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.solanaPurple.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Text(label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        );
      case _StepState.done:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.solanaTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.solanaTeal.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 12, color: AppColors.solanaTeal),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.solanaTeal,
                  )),
            ],
          ),
        );
      case _StepState.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outlineSoft),
          ),
          child: Text(label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceMuted,
              )),
        );
    }
  }
}

class _AdaptersComingSoonStrip extends StatelessWidget {
  final void Function(String) onTap;
  const _AdaptersComingSoonStrip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final adapters = const [
      ('Oura', Icons.nightlight_round),
      ('Whoop', Icons.fitness_center),
      ('Ray-Ban Meta', Icons.camera_alt_outlined),
      ('Apple Health', Icons.favorite_outline),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Roadmap adapters',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SOON',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurfaceDim,
                      letterSpacing: 0.6,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (name, icon) in adapters)
                InkWell(
                  onTap: () => onTap(name),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineSoft),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 12, color: AppColors.onSurfaceDim),
                        const SizedBox(width: 4),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceMuted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySessionsCard extends StatelessWidget {
  const _EmptySessionsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text('No sessions yet',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const SizedBox(height: 4),
          Text(
            'Load a demo or import a MuseLog CSV to start the on-chain consent flow.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _SolanaFooter extends StatelessWidget {
  const _SolanaFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) =>
                AppColors.brandGradient.createShader(rect),
            child: const Icon(Icons.token, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(
            'Built on Solana • devnet',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceDim,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
