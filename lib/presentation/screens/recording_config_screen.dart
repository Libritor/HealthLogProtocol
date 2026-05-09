import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/oura_provider.dart';
import '../providers/rayban_provider.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import 'live_session_screen.dart';

class RecordingConfigScreen extends ConsumerStatefulWidget {
  const RecordingConfigScreen({super.key});

  @override
  ConsumerState<RecordingConfigScreen> createState() =>
      _RecordingConfigScreenState();
}

class _RecordingConfigScreenState
    extends ConsumerState<RecordingConfigScreen> {
  final _sessionNameController = TextEditingController();
  final _notesController = TextEditingController();
  final Map<String, TextEditingController> _deviceNameControllers = {};

  @override
  void initState() {
    super.initState();
    _sessionNameController.text =
        'Session ${DateTime.now().toIso8601String().substring(0, 10)}';
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _notesController.dispose();
    for (final c in _deviceNameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String deviceId, String fallback) {
    return _deviceNameControllers.putIfAbsent(
      deviceId,
      () => TextEditingController(text: fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevices = ref.watch(selectedDevicesProvider);
    final selectedColumns = ref.watch(selectedColumnsProvider);
    final ouraAuth = ref.watch(ouraAuthStateProvider);
    final raybanSelected = ref.watch(raybanSelectedProvider);
    final hasMuse = selectedDevices.isNotEmpty;
    final hasOura = ouraAuth.status == OuraConnectionStatus.connected;
    final hasRayBan = raybanSelected.isNotEmpty;

    final canStart = (hasMuse || hasOura || hasRayBan) &&
        (!hasMuse || selectedColumns.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(title: const Text('Configure Recording')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sessionInfoCard(
                  hasMuse: hasMuse,
                  selectedDevices: selectedDevices,
                  hasOura: hasOura,
                  hasRayBan: hasRayBan,
                  raybanCount: raybanSelected.length,
                ),
                if (hasMuse) ...[
                  const SizedBox(height: 16),
                  _deviceNamesCard(selectedDevices),
                  const SizedBox(height: 16),
                  _dataColumnsCard(selectedColumns),
                ],
                if (hasOura) ...[
                  const SizedBox(height: 16),
                  _ouraCard(),
                ],
              ],
            ),
          ),
          _startButton(canStart),
        ],
      ),
    );
  }

  Widget _sessionInfoCard({
    required bool hasMuse,
    required Set<String> selectedDevices,
    required bool hasOura,
    required bool hasRayBan,
    required int raybanCount,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Info',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sessionNameController,
              decoration: const InputDecoration(
                labelText: 'Session Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasMuse)
                  Chip(
                    avatar: const Icon(Icons.headset, size: 16),
                    label: Text('${selectedDevices.length} Muse device(s)'),
                  ),
                if (hasOura)
                  const Chip(
                    avatar: Icon(Icons.ring_volume, size: 16),
                    label: Text('Oura Ring'),
                  ),
                if (hasRayBan)
                  Chip(
                    avatar: const Icon(Icons.visibility, size: 16),
                    label: Text('$raybanCount Ray-Ban media'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceNamesCard(Set<String> selectedDevices) {
    final connected = ref.watch(connectedDevicesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Names',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Rename each Muse to identify who is wearing it',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...selectedDevices.map((deviceId) {
              final device = connected[deviceId];
              final fallback = device?.name ?? deviceId;
              final controller = _controllerFor(deviceId, fallback);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: device?.name ?? deviceId,
                    hintText: 'e.g. Steve, Alex, Friends',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.headset),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: 'Reset to default',
                      onPressed: () {
                        controller.text = fallback;
                        ref
                            .read(deviceNamesProvider.notifier)
                            .rename(deviceId, fallback);
                      },
                    ),
                  ),
                  onChanged: (value) {
                    if (value.trim().isNotEmpty) {
                      ref
                          .read(deviceNamesProvider.notifier)
                          .rename(deviceId, value);
                    }
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _dataColumnsCard(Set<String> selectedColumns) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Data Columns',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${selectedColumns.length}/${AppConstants.csvColumns.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    ref
                        .read(selectedColumnsProvider.notifier)
                        .selectAll();
                  },
                  child: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    ref.read(selectedColumnsProvider.notifier).clearAll();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...AppConstants.columnGroups.entries.map((entry) {
              final groupName = entry.key;
              final groupColumns = entry.value;
              final allSelected =
                  groupColumns.every(selectedColumns.contains);
              final someSelected =
                  groupColumns.any(selectedColumns.contains);
              return CheckboxListTile(
                title: Text(groupName),
                subtitle: Text('${groupColumns.length} columns'),
                value: allSelected,
                tristate: true,
                onChanged: (checked) {
                  ref.read(selectedColumnsProvider.notifier).toggleGroup(
                        groupName,
                        checked ?? !allSelected,
                      );
                },
                secondary: someSelected && !allSelected
                    ? const Icon(Icons.indeterminate_check_box)
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _ouraCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ring_volume, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'Oura Ring Data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Today's sleep, activity, readiness, heart rate, and HRV data "
              'will be fetched from the Oura API and saved alongside any Muse '
              'recordings.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _startButton(bool canStart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: canStart ? _startRecording : null,
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.solanaPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  void _startRecording() {
    final selectedDeviceIds = ref.read(selectedDevicesProvider).toList();
    final selectedColumns = ref.read(selectedColumnsProvider);
    final ouraAuth = ref.read(ouraAuthStateProvider);
    final hasOura = ouraAuth.status == OuraConnectionStatus.connected;
    final raybanSelected = ref.read(raybanSelectedProvider);

    ref.read(sessionConfigProvider.notifier).createConfig(
          selectedDeviceIds: selectedDeviceIds,
          selectedColumns: selectedColumns,
          sessionName: _sessionNameController.text,
          notes: _notesController.text,
          includeOura: hasOura,
          includeRayBan: raybanSelected.isNotEmpty,
          raybanMediaPaths: raybanSelected.toList(),
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LiveSessionScreen(),
      ),
    );
  }
}
