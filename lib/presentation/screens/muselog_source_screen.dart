import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/adapters/muselog_adapter.dart';
import '../providers/solana_providers.dart';
import 'device_selection_screen.dart';
import 'session_detail_screen.dart';

class MuseLogSourceScreen extends ConsumerStatefulWidget {
  const MuseLogSourceScreen({super.key});

  @override
  ConsumerState<MuseLogSourceScreen> createState() =>
      _MuseLogSourceScreenState();
}

class _MuseLogSourceScreenState extends ConsumerState<MuseLogSourceScreen> {
  bool _busy = false;

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final adapter = MuseLogAdapter();
      final session = await adapter.importSession(File(path));
      ref.read(sessionsProvider.notifier).addSession(session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MuseLog session imported.')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(sessionId: session.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadDemo() async {
    setState(() => _busy = true);
    try {
      final demoSvc = ref.read(demoDataServiceProvider);
      final wallet = ref.read(solanaServiceProvider).connectedWallet;
      final bundle = await demoSvc.loadDemoData(ownerWallet: wallet);
      ref.read(sessionsProvider.notifier).addSession(bundle.session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo MuseLog session loaded.')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SessionDetailScreen(sessionId: bundle.session.id),
          ),
        );
      }
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('MuseLog Brain Sensing')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              children: [
                Icon(Icons.psychology,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('MuseLog Brain Sensing',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'EEG + IMU sessions from Muse-class devices.\n'
                  'Record live sessions or import existing CSV data.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),

                _actionCard(
                  theme,
                  icon: Icons.bluetooth_connected,
                  title: 'Connect Muse Device',
                  subtitle:
                      'Pair your Muse 2, Muse S, or Muse S (Gen 2) '
                      'and record a live EEG session.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DeviceSelectionScreen()),
                  ),
                ),
                _actionCard(
                  theme,
                  icon: Icons.upload_file,
                  title: 'Import MuseLog CSV',
                  subtitle:
                      'Import an existing MuseLog session CSV file '
                      'into the HealthLog pipeline.',
                  onTap: _importCsv,
                ),
                _actionCard(
                  theme,
                  icon: Icons.science,
                  title: 'Load Demo Session',
                  subtitle:
                      'Load a synthetic EEG + IMU sample for '
                      'the Colosseum golden demo path.',
                  onTap: _loadDemo,
                ),
              ],
            ),
    );
  }

  Widget _actionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
