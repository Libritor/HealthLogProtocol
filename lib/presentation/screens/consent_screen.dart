import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../domain/models/solana_models.dart';
import '../providers/solana_providers.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ConsentScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _recipientController = TextEditingController();
  ConsentScope _scope = ConsentScope.aiSummaryOnly;
  ConsentPurpose _purpose = ConsentPurpose.aiAnalysis;
  DateTime _expiry = DateTime.now().add(const Duration(days: 30));
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _signConsent() async {
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a recipient wallet address.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final session =
          ref.read(sessionsProvider.notifier).getById(widget.sessionId);
      if (session == null) return;

      final solana = ref.read(solanaServiceProvider);
      if (solana.connectedWallet == null) {
        final wallet = await solana.connectWallet();
        ref.read(walletAddressProvider.notifier).state = wallet;
      }

      await solana.grantAccess(
        sessionId: session.id,
        manifestHash: session.manifestHash ?? '',
        recipientWallet: recipient,
        scope: _scope,
        expiresAt: _expiry,
        purpose: _purpose,
      );

      ref.read(sessionsProvider.notifier).updateSession(
            session.copyWith(onchainStatus: OnchainStatus.shared),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Access Token Issued: ${_scope.displayName} '
              'to ${_truncate(recipient, 12)}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        _recipientController.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeGrant(String grantId) async {
    setState(() => _busy = true);
    try {
      final solana = ref.read(solanaServiceProvider);
      await solana.revokeAccess(grantId: grantId);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Access Token'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.solanaPurple,
          labelColor: AppColors.onSurface,
          unselectedLabelColor: AppColors.onSurfaceMuted,
          tabs: const [
            Tab(text: 'Issue token'),
            Tab(text: 'Access log'),
          ],
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _grantTab(theme),
                _accessLogTab(theme),
              ],
            ),
    );
  }

  Widget _grantTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        TextField(
          controller: _recipientController,
          decoration: const InputDecoration(
            labelText: 'Recipient Wallet Address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ConsentScope>(
          initialValue: _scope,
          decoration: const InputDecoration(
            labelText: 'Data Scope',
            border: OutlineInputBorder(),
          ),
          items: ConsentScope.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
              .toList(),
          onChanged: (v) => setState(() => _scope = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ConsentPurpose>(
          initialValue: _purpose,
          decoration: const InputDecoration(
            labelText: 'Purpose',
            border: OutlineInputBorder(),
          ),
          items: ConsentPurpose.values
              .map((p) =>
                  DropdownMenuItem(value: p, child: Text(p.displayName)))
              .toList(),
          onChanged: (v) => setState(() => _purpose = v!),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Expiry Date'),
          subtitle: Text('${_expiry.year}-${_p(_expiry.month)}-${_p(_expiry.day)}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _expiry,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _expiry = picked);
          },
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _signConsent,
          icon: const Icon(Icons.verified_user),
          label: const Text('Sign + publish consent on Solana'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Text('Live Data Access Tokens',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.solanaTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('non-transferable',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.solanaTeal,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _grantsList(theme),
      ],
    );
  }

  Widget _grantsList(ThemeData theme) {
    return FutureBuilder<List<ConsentGrant>>(
      future:
          ref.read(solanaServiceProvider).getGrants(sessionId: widget.sessionId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Text('No grants yet.',
              style: TextStyle(color: Colors.grey));
        }
        return Column(
          children: snap.data!.map((g) => _grantCard(g, theme)).toList(),
        );
      },
    );
  }

  Widget _grantCard(ConsentGrant grant, ThemeData theme) {
    final statusColor = grant.isActive
        ? AppColors.solanaTeal
        : grant.revoked
            ? AppColors.danger
            : AppColors.warning;
    final statusText = grant.revoked
        ? 'Revoked'
        : grant.isExpired
            ? 'Expired'
            : 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
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
                child: const Icon(Icons.key_outlined,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Data Access Token',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.onSurfaceMuted,
                        )),
                    Text(grant.scope.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.45)),
                ),
                child: Text(statusText.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: statusColor,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _kv('Recipient', _truncate(grant.recipientWallet, 16)),
          _kv('Purpose', grant.purpose.displayName),
          _kv('Expires',
              '${grant.expiresAt.year}-${_p(grant.expiresAt.month)}-${_p(grant.expiresAt.day)}'),
          if (grant.onchainTxSignature != null)
            _kv('Tx', _truncate(grant.onchainTxSignature!, 16)),
          if (grant.isActive) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _revokeGrant(grant.grantId),
                icon: const Icon(Icons.block, size: 14),
                label: const Text('Revoke on-chain'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.5)),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceDim,
                    letterSpacing: 0.4)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _accessLogTab(ThemeData theme) {
    return FutureBuilder<List<AccessLog>>(
      future: ref
          .read(solanaServiceProvider)
          .getAccessHistory(sessionId: widget.sessionId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Center(child: Text('No access events yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.length,
          itemBuilder: (_, i) {
            final log = snap.data![i];
            return ListTile(
              leading: Icon(
                log.accessType == 'access_revoked'
                    ? Icons.block
                    : log.accessType == 'verification_check'
                        ? Icons.verified
                        : Icons.key,
                size: 20,
              ),
              title: Text(log.accessType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(log.notes ?? '', style: const TextStyle(fontSize: 12)),
              trailing: Text(
                '${_p(log.accessedAt.hour)}:${_p(log.accessedAt.minute)}',
                style: const TextStyle(fontSize: 11),
              ),
            );
          },
        );
      },
    );
  }

  String _truncate(String s, int len) =>
      s.length > len ? '${s.substring(0, len)}...' : s;

  String _p(int n) => n.toString().padLeft(2, '0');
}
