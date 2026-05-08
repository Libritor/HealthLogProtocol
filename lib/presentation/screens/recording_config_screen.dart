import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import '../providers/device_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/oura_provider.dart';
import '../providers/rayban_provider.dart';
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

  void _ensureDeviceNameControllers() {
    final selectedDevices = ref.read(selectedDevicesProvider);
    final deviceNames = ref.read(deviceNamesProvider);
    final connectedDevices = ref.read(connectedDevicesProvider);

    for (final deviceId in selectedDevices) {
      if (!_deviceNameControllers.containsKey(deviceId)) {
        final currentName = deviceNames[deviceId] ??
            connectedDevices[deviceId]?.name ??
            deviceId;
        _deviceNameControllers[deviceId] =
            TextEditingController(text: currentName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevices = ref.watch(selectedDevicesProvider);
    final selectedColumns = ref.watch(selectedColumnsProvider);
    final recordVideoEnabled = ref.watch(recordVideoEnabledProvider);
    final ouraAuth = ref.watch(ouraAuthStateProvider);
    final raybanSelected = ref.watch(raybanSelectedProvider);
    final hasMuseDevices = selectedDevices.isNotEmpty;
    final hasOura = ouraAuth.status == OuraConnectionStatus.connected;
    final hasRayBan = raybanSelected.isNotEmpty;

    _ensureDeviceNameControllers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Recording'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
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
                          children: [
                            if (hasMuseDevices)
                              Chip(
                                avatar: const Icon(Icons.headset, size: 16),
                                label: Text(
                                    '${selectedDevices.length} Muse device(s)'),
                              ),
                            if (hasOura)
                              Chip(
                                avatar:
                                    const Icon(Icons.ring_volume, size: 16),
                                label: const Text('Oura Ring'),
                                backgroundColor: Colors.green.shade50,
                              ),
                            if (hasRayBan)
                              Chip(
                                avatar:
                                    const Icon(Icons.visibility, size: 16),
                                label: Text(
                                    '${raybanSelected.length} Ray-Ban media'),
                                backgroundColor: Colors.blue.shade50,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (hasMuseDevices) ...[
                  const SizedBox(height: 16),
                  Card(
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
                            final connectedDevices =
                                ref.watch(connectedDevicesProvider);
                            final device = connectedDevices[deviceId];
                            final controller =
                                _deviceNameControllers[deviceId];

                            if (controller == null) {
                              return const SizedBox.shrink();
                            }

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
                                      final defaultName =
                                          device?.name ?? deviceId;
                                      controller.text = defaultName;
                                      ref
                                          .read(
                                              deviceNamesProvider.notifier)
                                          .rename(deviceId, defaultName);
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
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Record Video'),
                            subtitle: const Text(
                              'Record camera video synchronized with EEG data',
                            ),
                            secondary: Icon(
                              recordVideoEnabled
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              color:
                                  recordVideoEnabled ? Colors.red : null,
                            ),
                            value: recordVideoEnabled,
                            onChanged: (value) async {
                              if (value) {
                                final cameraStatus =
                                    await Permission.camera.request();
                                final micStatus =
                                    await Permission.microphone.request();
                                if (!cameraStatus.isGranted ||
                                    !micStatus.isGranted) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Camera and microphone permissions are required for video recording.',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }
                              ref
                                  .read(
                                      recordVideoEnabledProvider.notifier)
                                  .state = value;
                            },
                          ),
                          if (recordVideoEnabled) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 8),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.camera_alt, size: 20),
                                      SizedBox(width: 8),
                                      Text('Camera'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: SegmentedButton<
                                        CameraLensDirection>(
                                      segments: const [
                                        ButtonSegment(
                                          value:
                                              CameraLensDirection.back,
                                          label: Text('Back'),
                                        ),
                                        ButtonSegment(
                                          value:
                                              CameraLensDirection.front,
                                          label: Text('Front'),
                                        ),
                                      ],
                                      selected: {
                                        ref.watch(
                                            selectedCameraDirectionProvider)
                                      },
                                      onSelectionChanged: (selected) {
                                        ref
                                            .read(
                                                selectedCameraDirectionProvider
                                                    .notifier)
                                            .state = selected.first;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.screen_rotation,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text('Orientation'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child:
                                        SegmentedButton<VideoOrientation>(
                                      segments: const [
                                        ButtonSegment(
                                          value:
                                              VideoOrientation.landscape,
                                          label: Text('Landscape'),
                                        ),
                                        ButtonSegment(
                                          value:
                                              VideoOrientation.portrait,
                                          label: Text('Portrait'),
                                        ),
                                      ],
                                      selected: {
                                        ref.watch(
                                            selectedVideoOrientationProvider)
                                      },
                                      onSelectionChanged: (selected) {
                                        ref
                                            .read(
                                                selectedVideoOrientationProvider
                                                    .notifier)
                                            .state = selected.first;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Data Columns',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              Text(
                                '${selectedColumns.length}/${AppConstants.csvColumns.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  ref
                                      .read(
                                          selectedColumnsProvider.notifier)
                                      .selectAll();
                                },
                                child: const Text('Select All'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  ref
                                      .read(
                                          selectedColumnsProvider.notifier)
                                      .clearAll();
                                },
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...AppConstants.columnGroups.entries
                              .map((entry) {
                            final groupName = entry.key;
                            final groupColumns = entry.value;
                            final allSelected = groupColumns
                                .every(selectedColumns.contains);
                            final someSelected = groupColumns
                                .any(selectedColumns.contains);

                            return CheckboxListTile(
                              title: Text(groupName),
                              subtitle: Text(
                                  '${groupColumns.length} columns'),
                              value: allSelected,
                              tristate: true,
                              onChanged: (checked) {
                                ref
                                    .read(
                                        selectedColumnsProvider.notifier)
                                    .toggleGroup(
                                      groupName,
                                      checked ?? !allSelected,
                                    );
                              },
                              secondary:
                                  someSelected && !allSelected
                                      ? const Icon(
                                          Icons
                                              .indeterminate_check_box)
                                      : null,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],

                if (hasOura) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.ring_volume,
                                  color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Oura Ring Data',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Today\'s sleep, activity, readiness, heart rate, and HRV '
                            'data will be fetched from the Oura API and saved alongside '
                            'any Muse recordings.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Container(
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
                onPressed: (!hasMuseDevices && !hasOura && !hasRayBan)
                    ? null
                    : (hasMuseDevices && selectedColumns.isEmpty)
                        ? null
                        : _startRecording,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start Recording'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startRecording() {
    final selectedDeviceIds = ref.read(selectedDevicesProvider).toList();
    final selectedColumns = ref.read(selectedColumnsProvider);
    final recordVideo = ref.read(recordVideoEnabledProvider);
    final ouraAuth = ref.read(ouraAuthStateProvider);
    final hasOura = ouraAuth.status == OuraConnectionStatus.connected;
    final raybanSelected = ref.read(raybanSelectedProvider);

    ref.read(sessionConfigProvider.notifier).createConfig(
          selectedDeviceIds: selectedDeviceIds,
          selectedColumns: selectedColumns,
          sessionName: _sessionNameController.text,
          notes: _notesController.text,
          recordVideo: recordVideo,
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

  @override
  void dispose() {
    _sessionNameController.dispose();
    _notesController.dispose();
    for (final controller in _deviceNameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
