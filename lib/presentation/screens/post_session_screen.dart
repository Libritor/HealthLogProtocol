import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/adapters/muselog_adapter.dart';
import '../../data/storage/file_storage_helper.dart';
import '../../domain/models/solana_models.dart';
import '../providers/recording_provider.dart';
import '../providers/solana_providers.dart';
import 'device_selection_screen.dart';
import 'healthlog_dashboard_screen.dart';
import 'session_detail_screen.dart';

/// Post-session summary screen
/// Shows recording summary and allows sharing CSV files
class PostSessionScreen extends ConsumerStatefulWidget {
  const PostSessionScreen({super.key});

  @override
  ConsumerState<PostSessionScreen> createState() => _PostSessionScreenState();
}

class _PostSessionScreenState extends ConsumerState<PostSessionScreen> {
  List<File>? _sessionFiles;
  bool _isLoading = true;
  String? _importedSessionId;
  bool _healthLogBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSessionFiles();
  }

  Future<void> _loadSessionFiles() async {
    final files = await FileStorageHelper.listSessionFiles();
    final allFiles = <File>[...files.take(15)];

    final config = ref.read(sessionConfigProvider);
    if (config != null && config.includeRayBan) {
      for (final path in config.raybanMediaPaths) {
        final file = File(path);
        if (await file.exists()) {
          allFiles.add(file);
        }
      }
    }

    setState(() {
      _sessionFiles = allFiles;
      _isLoading = false;
    });
  }

  Future<WearableSession?> _ensureImported() async {
    if (_importedSessionId != null) {
      return ref.read(sessionsProvider.notifier).getById(_importedSessionId!);
    }
    final csvFiles = _sessionFiles
        ?.where((f) => f.path.toLowerCase().endsWith('.csv'))
        .toList();
    if (csvFiles == null || csvFiles.isEmpty) return null;

    final adapter = MuseLogAdapter();
    final session = await adapter.importSession(csvFiles.first);
    ref.read(sessionsProvider.notifier).addSession(session);
    setState(() => _importedSessionId = session.id);
    return session;
  }

  Future<void> _createManifest() async {
    setState(() => _healthLogBusy = true);
    try {
      final session = await _ensureImported();
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HealthLog manifest created.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _healthLogBusy = false);
    }
  }

  Future<void> _encryptSession() async {
    setState(() => _healthLogBusy = true);
    try {
      final session = await _ensureImported();
      if (session == null || session.rawFileUri == null) return;

      final svc = ref.read(encryptionServiceProvider);
      final result = await svc.encryptFile(File(session.rawFileUri!));
      ref.read(sessionsProvider.notifier).updateSession(
            session.copyWith(
              encryptedFileUri: result.encryptedFile.path,
              encryptionStatus: SessionEncryptionStatus.encrypted,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session encrypted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _healthLogBusy = false);
    }
  }

  Future<void> _openInHealthLog() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HealthLogDashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _generateAISummary() async {
    setState(() => _healthLogBusy = true);
    try {
      final session = await _ensureImported();
      if (session == null) return;

      if (session.manifestHash == null) {
        await _createManifest();
      }
      final refreshed =
          ref.read(sessionsProvider.notifier).getById(session.id);
      if (refreshed == null || refreshed.manifestHash == null) return;

      final aiSvc = ref.read(aiReportServiceProvider);
      final report = await aiSvc.generateSessionSummary(
        session: refreshed,
        manifestHash: refreshed.manifestHash!,
      );
      ref.read(aiReportsProvider.notifier).addReport(report);
      ref.read(sessionsProvider.notifier).updateSession(
            refreshed.copyWith(aiSummaryStatus: AISummaryStatus.generated),
          );

      if (mounted) {
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
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _healthLogBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(sessionConfigProvider);
    final recordingManager = ref.read(recordingManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Complete'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Success icon
                  const Center(
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Session summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Summary',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          _buildSummaryRow('Session Name', config?.sessionName ?? 'Unknown'),
                          _buildSummaryRow(
                            'Duration',
                            _formatDuration(recordingManager.elapsedSeconds),
                          ),
                          _buildSummaryRow(
                            'Muse Devices',
                            '${config?.selectedDeviceIds.length ?? 0}',
                          ),
                          _buildSummaryRow(
                            'Oura Ring',
                            (config?.includeOura ?? false) ? 'Yes' : 'No',
                          ),
                          _buildSummaryRow(
                            'Ray-Ban Media',
                            (config?.includeRayBan ?? false)
                                ? '${config!.raybanMediaPaths.length} files'
                                : 'No',
                          ),
                          _buildSummaryRow(
                            'Columns Recorded',
                            '${config?.selectedColumns.length ?? 0}',
                          ),
                          _buildSummaryRow(
                            'Video Recorded',
                            (config?.recordVideo ?? false) ? 'Yes' : 'No',
                          ),
                          if (config?.notes.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Notes:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(config!.notes),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Recorded files (CSV + video)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recorded Files',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          if (_sessionFiles == null || _sessionFiles!.isEmpty)
                            const Text('No files found')
                          else
                            ..._sessionFiles!.map((file) => _buildFileRow(file)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Share all button
                  if (_sessionFiles != null && _sessionFiles!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareAllFiles,
                        icon: const Icon(Icons.share),
                        label: const Text('Share All Session Files'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // New session button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _startNewSession,
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Session'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // HealthLog Actions
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.health_and_safety,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                              const SizedBox(width: 8),
                              Text('HealthLog Actions',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 24),
                          _healthLogButton(
                            Icons.arrow_forward,
                            'Continue to HealthLog',
                            _openInHealthLog,
                          ),
                          _healthLogButton(
                            Icons.fingerprint,
                            'Create HealthLog Manifest',
                            _createManifest,
                          ),
                          _healthLogButton(
                            Icons.lock,
                            'Encrypt Session',
                            _encryptSession,
                          ),
                          _healthLogButton(
                            Icons.auto_awesome,
                            'Generate AI Summary',
                            _generateAISummary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _healthLogButton(
      IconData icon, String label, Future<void> Function() onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        onPressed: _healthLogBusy ? null : () => onPressed(),
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildFileRow(File file) {
    final fileName = file.uri.pathSegments.last;
    final fileSize = FileStorageHelper.formatFileSize(file.lengthSync());
    final ext = fileName.split('.').last.toLowerCase();
    final isVideo = {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(ext);
    final isImage = {'jpg', 'jpeg', 'png', 'heic', 'heif'}.contains(ext);

    IconData icon;
    String typeLabel;
    if (isVideo) {
      icon = Icons.videocam;
      typeLabel = 'Video';
    } else if (isImage) {
      icon = Icons.image;
      typeLabel = 'Photo';
    } else {
      icon = Icons.insert_drive_file;
      typeLabel = 'CSV';
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(
        fileName,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text('$typeLabel · $fileSize'),
      trailing: IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _shareFile(file),
      ),
      onTap: () => _showFileInfo(file),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes min $secs sec';
  }

  Future<void> _shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'HealthLog Session Data',
      text: 'HealthLog session recording data',
    );
  }

  Future<void> _shareAllFiles() async {
    if (_sessionFiles == null || _sessionFiles!.isEmpty) return;

    await Share.shareXFiles(
      _sessionFiles!.map((f) => XFile(f.path)).toList(),
      subject: 'HealthLog Session Data',
      text: 'HealthLog session recording data (EEG, Oura, Ray-Ban, video)',
    );
  }

  void _showFileInfo(File file) {
    final path = FileStorageHelper.getDisplayPath(file);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Location'),
        content: SelectableText(path),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startNewSession() {
    // Reset session config
    ref.read(sessionConfigProvider.notifier).clearConfig();
    ref.read(recordingStateProvider.notifier).reset();
    ref.read(selectedColumnsProvider.notifier).selectAll();

    // Navigate back to device selection
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const DeviceSelectionScreen(),
      ),
      (route) => false,
    );
  }
}
