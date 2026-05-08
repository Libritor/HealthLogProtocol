import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../data/crypto/merkle_proof_service.dart';
import '../../data/crypto/verification_service.dart';
import '../../domain/models/solana_models.dart';
import '../providers/solana_providers.dart';

class VerifierScreen extends ConsumerStatefulWidget {
  const VerifierScreen({super.key});

  @override
  ConsumerState<VerifierScreen> createState() => _VerifierScreenState();
}

class _VerifierScreenState extends ConsumerState<VerifierScreen> {
  final _sessionIdController = TextEditingController();
  final _walletController = TextEditingController();
  GrantVerification? _grantResult;
  List<VerificationResult>? _claimResults;
  MerkleProof? _merkleProof;
  bool _busy = false;

  Future<void> _useLatestDemo() async {
    final sessions = ref.read(sessionsProvider);
    if (sessions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No sessions yet. Load a demo session first.')),
        );
      }
      return;
    }
    final latest = sessions.first;
    _sessionIdController.text = latest.id;

    try {
      final solana = ref.read(solanaServiceProvider);
      final grants = await solana.getGrants(sessionId: latest.id);
      if (grants.isNotEmpty) {
        _walletController.text = grants.first.recipientWallet;
      }
    } catch (_) {}
    setState(() {});
  }

  Future<void> _verify() async {
    final sessionId = _sessionIdController.text.trim();
    final wallet = _walletController.text.trim();
    if (sessionId.isEmpty || wallet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter session ID and wallet address.')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _grantResult = null;
      _claimResults = null;
      _merkleProof = null;
    });

    try {
      final solana = ref.read(solanaServiceProvider);
      final verification = await solana.verifyGrant(
        sessionId: sessionId,
        recipientWallet: wallet,
      );

      final verificationSvc = ref.read(verificationServiceProvider);
      final session =
          ref.read(sessionsProvider.notifier).getById(sessionId);
      final grants = await solana.getGrants(sessionId: sessionId);
      final grant = grants.where((g) => g.recipientWallet == wallet).lastOrNull;
      final report = ref.read(aiReportsProvider)[sessionId];

      final claims = <VerificationResult>[];

      if (session != null) {
        claims.add(await verificationSvc.verifySessionOwnership(
          sessionId: sessionId,
          ownerWallet: session.ownerWallet ?? '',
          manifestHash: session.manifestHash ?? '',
        ));
      }

      if (grant != null) {
        claims.add(await verificationSvc.verifyConsentScope(
          grant: grant,
          requestedScope: ConsentScope.aiSummaryOnly,
        ));
        claims.add(await verificationSvc.verifyNegativeScope(
          grant: grant,
          deniedScope: ConsentScope.rawEncryptedSession,
        ));
      }

      if (report != null && session != null) {
        claims.add(await verificationSvc.verifyAIReportChain(
          report: report,
          manifestHash: session.manifestHash ?? '',
        ));
      }

      if (session != null) {
        claims.add(await verificationSvc.verifySessionAfterDate(
          session: session,
          afterDate: DateTime(2020),
        ));
      }

      // Build a Merkle inclusion proof over all committed manifest hashes.
      // This shows that the verified session is part of the user's
      // committed set without revealing the contents of the other sessions.
      MerkleProof? proof;
      if (session?.manifestHash != null) {
        final allSessions = ref.read(sessionsProvider);
        final manifestHashes = allSessions
            .map((s) => s.manifestHash)
            .whereType<String>()
            .toList(growable: false);
        if (manifestHashes.contains(session!.manifestHash)) {
          final merkle = ref.read(merkleProofServiceProvider);
          final tree = merkle.buildTree(manifestHashes);
          proof = merkle.proveInclusion(
            tree: tree,
            target: session.manifestHash!,
          );
        }
      }

      setState(() {
        _grantResult = verification;
        _claimResults = claims;
        _merkleProof = proof;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _sessionIdController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = ref.watch(solanaModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Access'),
        actions: [
          _MiniModeChip(mode: mode),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        children: [
          Text(
            'Privacy-preserving verification — proves access without revealing data.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _useLatestDemo,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Use latest demo session'),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _sessionIdController,
            decoration: const InputDecoration(
              labelText: 'Session ID',
              helperText: 'Identifier of the wearable session to verify.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _walletController,
            decoration: const InputDecoration(
              labelText: 'Recipient wallet address',
              helperText: 'Wallet that holds the access token.',
            ),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _busy ? null : _verify,
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Run verification'),
          ),
          const SizedBox(height: 24),

          if (_grantResult == null && _claimResults == null && !_busy)
            _checklistPreview(theme),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_grantResult != null) _grantResultCard(theme),
          if (_claimResults != null && _claimResults!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _claimsCard(theme),
          ],
          if (_merkleProof != null) ...[
            const SizedBox(height: 16),
            _merkleProofCard(theme, _merkleProof!),
          ],
        ],
      ),
    );
  }

  Widget _checklistPreview(ThemeData theme) {
    const checks = [
      'Manifest hash matches on-chain commitment',
      'Owner wallet signature is valid',
      'Access grant is active and not revoked',
      'Data access token is active',
      'AI report hash matches committed session',
      'Permitted scope matches request',
      'Raw health data is not exposed',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist,
                    size: 18, color: AppColors.solanaPurple),
                const SizedBox(width: 8),
                Text('Verification checklist',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...checks.map((check) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.circle_outlined,
                          size: 14, color: AppColors.onSurfaceDim),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(check,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.onSurfaceMuted)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _grantResultCard(ThemeData theme) {
    final v = _grantResult!;
    final allPassed = v.allPassed;
    final accent = allPassed ? AppColors.solanaTeal : AppColors.danger;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(allPassed ? Icons.check_circle : Icons.cancel,
                  color: accent, size: 26),
              const SizedBox(width: 8),
              Text(
                allPassed ? 'Access verified' : 'Access denied',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          if (v.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(v.errorMessage!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w500,
                )),
          ],
          const SizedBox(height: 16),
          ...v.checks.map((c) => _checkRow(c.label, c.passed)),
          if (allPassed) ...[
            const SizedBox(height: 12),
            _scopeIndicator(),
          ] else ...[
            const SizedBox(height: 12),
            _denialBlurb(),
          ],
        ],
      ),
    );
  }

  Widget _denialBlurb() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.30)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, color: AppColors.danger, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'The recipient does not have valid access. Raw health data was not exposed.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _claimsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 18, color: AppColors.solanaPurple),
                const SizedBox(width: 8),
                Text('Privacy-preserving claims',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('ZK-ready verification interface',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 12),
            ..._claimResults!.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _checkRow(c.claimDescription, c.isValid),
                      Padding(
                        padding: const EdgeInsets.only(left: 22, top: 2),
                        child: Text(
                          'Proof: ${c.proofType} • ${c.proofData.substring(0, 16)}…',
                          style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppColors.onSurfaceDim),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _merkleProofCard(ThemeData theme, MerkleProof proof) {
    final merkleSvc = ref.read(merkleProofServiceProvider);
    final verified = merkleSvc.verifyProof(proof);
    final accent = verified ? AppColors.solanaTeal : AppColors.danger;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Cryptographic inclusion proof',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      verified
                          ? 'Session is in the committed set. Other manifests stay private.'
                          : 'Inclusion failed. Recompute the tree.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  verified ? 'VERIFIED' : 'FAILED',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _hashLine('leaf', proof.leaf),
          _hashLine('hashed leaf', proof.hashedLeaf),
          for (var i = 0; i < proof.siblings.length; i++)
            _hashLine(
              'sibling[$i] ${proof.siblings[i].position == SiblingPosition.left ? "←" : "→"}',
              proof.siblings[i].hash,
            ),
          _hashLine('root', proof.root, highlight: true),
          const SizedBox(height: 8),
          Text(
            'Light Protocol ZK compression on the roadmap — '
            'compressed accounts will let us anchor this root on-chain at <1k lamports each.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hashLine(String label, String value, {bool highlight = false}) {
    final shown =
        value.length > 18 ? '${value.substring(0, 10)}…${value.substring(value.length - 6)}' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: highlight
                    ? AppColors.solanaTeal
                    : AppColors.onSurfaceDim,
              ),
            ),
          ),
          Expanded(
            child: Text(
              shown,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: highlight
                    ? AppColors.solanaTeal
                    : AppColors.onSurface,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.copy, size: 12),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _checkRow(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: passed ? AppColors.solanaTeal : AppColors.danger,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _scopeIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.solanaTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.solanaTeal.withValues(alpha: 0.25)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permitted access',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.onSurface)),
          SizedBox(height: 6),
          _ScopeRow(label: 'AI summary', allowed: true),
          _ScopeRow(label: 'Raw EEG', allowed: false),
          _ScopeRow(label: 'Raw PPG / fNIRS / IMU', allowed: false),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  final String label;
  final bool allowed;
  const _ScopeRow({required this.label, required this.allowed});

  @override
  Widget build(BuildContext context) {
    final color = allowed ? AppColors.solanaTeal : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(allowed ? Icons.check : Icons.close, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

class _MiniModeChip extends StatelessWidget {
  final SolanaMode mode;
  const _MiniModeChip({required this.mode});

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
