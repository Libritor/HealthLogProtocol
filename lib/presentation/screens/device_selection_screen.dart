import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../providers/oura_provider.dart';
import '../providers/rayban_provider.dart';
import 'past_recordings_screen.dart';
import 'rayban_gallery_screen.dart';
import '../../data/storage/file_storage_helper.dart';
import '../../domain/models/oura_data.dart';
import '../../domain/models/rayban_media.dart';
import '../../features/arousal/presentation/screens/session_gateway_screen.dart';

class DeviceSelectionScreen extends ConsumerStatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  ConsumerState<DeviceSelectionScreen> createState() =>
      _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState
    extends ConsumerState<DeviceSelectionScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isStartingSession = false;
  late TabController _tabController;
  final _ouraTokenController = TextEditingController();
  DateTime _ouraHistoryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevices = ref.watch(selectedDevicesProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider);
    final ouraAuth = ref.watch(ouraAuthStateProvider);
    final raybanSelected = ref.watch(raybanSelectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(
              icon: Icon(Icons.headset),
              text: 'Muse Headband',
            ),
            Tab(
              icon: Icon(
                Icons.ring_volume,
                color: ouraAuth.status == OuraConnectionStatus.connected
                    ? Colors.green
                    : null,
              ),
              text: 'Oura Ring',
            ),
            Tab(
              icon: Icon(
                Icons.visibility,
                color: raybanSelected.isNotEmpty ? Colors.green : null,
              ),
              text: 'Ray-Ban Meta',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMuseTab(),
                _buildOuraTab(),
                _buildRayBanTab(),
              ],
            ),
          ),

          SafeArea(
            child: Container(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildConnectionSummary(
                      selectedDevices, connectedDevices, ouraAuth),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              selectedDevices.isEmpty ? null : _connectSelected,
                          child: const Text('Connect Selected'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (selectedDevices.isEmpty &&
                                  ouraAuth.status !=
                                      OuraConnectionStatus.connected &&
                                  raybanSelected.isEmpty)
                              ? null
                              : _isStartingSession
                              ? null
                              : _startSession,
                          child: _isStartingSession
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Start Session'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _viewPastRecordings,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Past Recordings'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _recoverLostFiles,
                          icon: const Icon(Icons.restore),
                          label: const Text('Recover Files'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Connection summary chip row
  // ---------------------------------------------------------------------------

  Widget _buildConnectionSummary(
    Set<String> selectedDevices,
    Map<String, dynamic> connectedDevices,
    OuraAuthState ouraAuth,
  ) {
    final museCount = selectedDevices.length;
    final ouraConnected =
        ouraAuth.status == OuraConnectionStatus.connected;
    final raybanSelected = ref.watch(raybanSelectedProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        if (museCount > 0)
          Chip(
            avatar: const Icon(Icons.headset, size: 18),
            label: Text('$museCount Muse selected'),
          ),
        if (ouraConnected)
          Chip(
            avatar: const Icon(Icons.ring_volume, size: 18),
            label: const Text('Oura connected'),
            backgroundColor: Colors.green.shade50,
          ),
        if (raybanSelected.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.visibility, size: 18),
            label: Text('${raybanSelected.length} Ray-Ban media'),
            backgroundColor: Colors.blue.shade50,
          ),
        if (museCount == 0 && !ouraConnected && raybanSelected.isEmpty)
          Text(
            'No devices selected',
            style: Theme.of(context).textTheme.titleSmall,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Muse tab
  // ---------------------------------------------------------------------------

  Widget _buildMuseTab() {
    final deviceScanAsync = ref.watch(deviceScanProvider);
    final selectedDevices = ref.watch(selectedDevicesProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: Icon(_isScanning
                      ? Icons.bluetooth_searching
                      : Icons.bluetooth),
                  label: Text(
                      _isScanning ? 'Scanning...' : 'Scan for Muse Devices'),
                ),
              ),
              if (_isScanning) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _stopScan,
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop Scan',
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: deviceScanAsync.when(
            data: (devices) {
              if (devices.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_disabled,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No Muse devices found'),
                      SizedBox(height: 8),
                      Text('Tap "Scan for Muse Devices" to start'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: devices.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final isSelected = selectedDevices.contains(device.id);
                  final isConnected =
                      connectedDevices.containsKey(device.id);

                  final displayDevice =
                      connectedDevices[device.id] ?? device;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        ref
                            .read(selectedDevicesProvider.notifier)
                            .toggleDevice(device.id);
                      },
                      title: Text(
                        device.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${device.id}'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isConnected
                                    ? Icons.link
                                    : Icons.link_off,
                                size: 16,
                                color: isConnected
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isConnected
                                    ? 'Connected'
                                    : 'Disconnected',
                                style: TextStyle(
                                  color: isConnected
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      secondary: (isConnected &&
                              displayDevice.batteryPercent > 0)
                          ? Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.battery_std),
                                Text('${displayDevice.batteryPercent}%'),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Oura Ring tab
  // ---------------------------------------------------------------------------

  Widget _buildOuraTab() {
    final ouraAuth = ref.watch(ouraAuthStateProvider);

    switch (ouraAuth.status) {
      case OuraConnectionStatus.disconnected:
      case OuraConnectionStatus.error:
        return _buildOuraSignIn(ouraAuth);
      case OuraConnectionStatus.connecting:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to Oura...'),
            ],
          ),
        );
      case OuraConnectionStatus.connected:
        return _buildOuraConnected(ouraAuth);
    }
  }

  Widget _buildOuraSignIn(OuraAuthState ouraAuth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.ring_volume,
            size: 72,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 24),
          Text(
            'Connect Oura Ring 3',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your Oura Personal Access Token to pull sleep, '
            'activity, readiness, heart rate, and HRV data from your ring.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _ouraTokenController,
            decoration: InputDecoration(
              labelText: 'Personal Access Token',
              hintText: 'Paste your Oura PAT here',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _ouraTokenController.clear(),
              ),
            ),
            obscureText: true,
            maxLines: 1,
          ),
          const SizedBox(height: 16),

          if (ouraAuth.status == OuraConnectionStatus.error &&
              ouraAuth.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ouraAuth.errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ElevatedButton.icon(
            onPressed: _connectOura,
            icon: const Icon(Icons.login),
            label: const Text('Connect'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to get your token:',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _instructionStep('1', 'Go to cloud.ouraring.com/personal-access-tokens'),
                _instructionStep('2', 'Sign in with your Oura account'),
                _instructionStep('3', 'Create a new Personal Access Token'),
                _instructionStep('4', 'Copy and paste the token above'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildOuraConnected(OuraAuthState ouraAuth) {
    final device = ouraAuth.device!;
    final selectedDate = DateTime(
      _ouraHistoryDate.year,
      _ouraHistoryDate.month,
      _ouraHistoryDate.day,
    );
    final summaryAsync = ref.watch(ouraDailySummaryProvider(selectedDate));
    final isToday = _isSameDay(selectedDate, DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.ring_volume,
                      size: 48,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    device.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Connected',
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ],
                  ),
                  if (device.email != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      device.email!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Data',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _dataTypeRow(Icons.nightlight_round, 'Sleep',
                      'Duration, stages, score'),
                  _dataTypeRow(Icons.directions_run, 'Activity',
                      'Steps, calories, active minutes'),
                  _dataTypeRow(Icons.speed, 'Readiness',
                      'Recovery score, temperature'),
                  _dataTypeRow(Icons.favorite, 'Heart Rate',
                      'Continuous HR measurements'),
                  _dataTypeRow(Icons.timeline, 'HRV',
                      'Heart rate variability (RMSSD)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Past Oura Data',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: isToday
                            ? null
                            : () {
                                setState(() => _ouraHistoryDate = DateTime.now());
                              },
                        child: const Text('Today'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(
                            () => _ouraHistoryDate =
                                selectedDate.subtract(const Duration(days: 1)),
                          );
                        },
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous day',
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: selectedDate.isBefore(
                          DateTime.now().subtract(const Duration(days: 1)),
                        )
                            ? () {
                                setState(
                                  () => _ouraHistoryDate =
                                      selectedDate.add(const Duration(days: 1)),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next day',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  summaryAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Failed to load: $error',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    data: (summary) => _buildOuraHistorySummary(summary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _disconnectOura,
            icon: const Icon(Icons.logout),
            label: const Text('Disconnect Oura Ring'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOuraHistorySummary(OuraDailySummary summary) {
    final hasAnyData = summary.sleep != null ||
        summary.activity != null ||
        summary.readiness != null ||
        summary.stress != null ||
        summary.heartRates.isNotEmpty ||
        summary.hrvSamples.isNotEmpty;

    if (!hasAnyData) {
      return Text(
        'No Oura data available for this day yet.',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      );
    }

    return Column(
      children: [
        if (summary.sleep != null)
          _historyMetricTile(
            icon: Icons.nightlight_round,
            label: 'Sleep score',
            value: '${summary.sleep!.score}',
          ),
        if (summary.activity != null)
          _historyMetricTile(
            icon: Icons.directions_run,
            label: 'Activity score',
            value: '${summary.activity!.score}',
          ),
        if (summary.readiness != null)
          _historyMetricTile(
            icon: Icons.speed,
            label: 'Readiness score',
            value: '${summary.readiness!.score}',
          ),
        if (summary.stress != null)
          _historyMetricTile(
            icon: Icons.self_improvement,
            label: 'Stress day summary',
            value: summary.stress!.daySummary.toUpperCase(),
          ),
        if (summary.heartRates.isNotEmpty)
          _historyMetricTile(
            icon: Icons.favorite,
            label: 'Latest heart rate',
            value: '${summary.heartRates.last.bpm} bpm',
          ),
        if (summary.hrvSamples.isNotEmpty)
          _historyMetricTile(
            icon: Icons.timeline,
            label: 'Latest HRV',
            value: '${summary.hrvSamples.last.rmssd.toStringAsFixed(1)} ms',
          ),
      ],
    );
  }

  Widget _historyMetricTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _dataTypeRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Oura actions
  // ---------------------------------------------------------------------------

  void _connectOura() {
    final token = _ouraTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Oura Personal Access Token.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    ref.read(ouraAuthStateProvider.notifier).authenticate(token);
  }

  void _disconnectOura() {
    ref.read(ouraAuthStateProvider.notifier).signOut();
    _ouraTokenController.clear();
  }

  // ---------------------------------------------------------------------------
  // Ray-Ban Meta tab
  // ---------------------------------------------------------------------------

  Widget _buildRayBanTab() {
    final mediaState = ref.watch(raybanScannedMediaProvider);
    final selected = ref.watch(raybanSelectedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Import photos and videos synced from your Ray-Ban Meta glasses '
                    'via the Meta View app, or pick files manually.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: mediaState.isScanning
                      ? null
                      : () => _scanRayBanMedia(),
                  icon: mediaState.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(mediaState.isScanning ? 'Scanning...' : 'Scan for Media'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickRayBanMedia(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Pick Files'),
                ),
              ),
            ],
          ),
          if (mediaState.error != null) ...[
            const SizedBox(height: 8),
            Text(
              mediaState.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (mediaState.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${mediaState.items.length} files found',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        ref
                            .read(raybanSelectedProvider.notifier)
                            .selectAll(mediaState.items);
                      },
                      child: const Text('Select All'),
                    ),
                    if (selected.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref.read(raybanSelectedProvider.notifier).clearAll();
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
            if (selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${selected.length} selected for session',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ...mediaState.items.take(50).map(
                  (item) => _buildRayBanMediaTile(item, selected.contains(item.path)),
                ),
            if (mediaState.items.length > 50)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton(
                  onPressed: () => _openRayBanGallery(),
                  child: Text(
                    'View all ${mediaState.items.length} files in gallery',
                  ),
                ),
              ),
          ] else if (!mediaState.isScanning) ...[
            const SizedBox(height: 48),
            Icon(Icons.visibility, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Ray-Ban media found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Scan for Media" to search your phone storage, '
              'or "Pick Files" to manually select photos and videos.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (mediaState.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openRayBanGallery(),
              icon: const Icon(Icons.grid_view),
              label: const Text('Open Full Gallery'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRayBanMediaTile(RayBanMediaItem item, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: item.isVideo ? Colors.purple.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.isPhoto
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(item.path),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image,
                      color: Colors.blue.shade300,
                    ),
                  ),
                )
              : Icon(
                  Icons.videocam,
                  color: Colors.purple.shade300,
                ),
        ),
        title: Text(
          item.filename,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${item.isVideo ? "Video" : "Photo"} · ${item.fileSizeFormatted}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (_) {
            ref.read(raybanSelectedProvider.notifier).toggle(item.path);
          },
        ),
        onTap: () {
          ref.read(raybanSelectedProvider.notifier).toggle(item.path);
        },
      ),
    );
  }

  Future<void> _scanRayBanMedia() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();
      final anyGranted = statuses.values.any((s) => s.isGranted);
      if (!anyGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to scan for media.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
    ref.read(raybanScannedMediaProvider.notifier).scan();
  }

  void _pickRayBanMedia() {
    ref.read(raybanScannedMediaProvider.notifier).pickManually();
  }

  void _openRayBanGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RayBanGalleryScreen(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Muse actions (unchanged)
  // ---------------------------------------------------------------------------

  void _startScan() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    if (!allGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Bluetooth and Location permissions are required to scan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
    });

    ref.invalidate(deviceScanProvider);
  }

  Future<void> _stopScan() async {
    await ref.read(museServiceProvider).stopScanning();
    if (!mounted) return;
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectSelected() async {
    final selectedDeviceIds = ref.read(selectedDevicesProvider).toList();
    final museService = ref.read(museServiceProvider);
    final connectedNotifier = ref.read(connectedDevicesProvider.notifier);
    final deviceList = ref.read(deviceScanProvider).value ?? [];

    final futures = selectedDeviceIds.map((deviceId) async {
      try {
        await museService.connectToDevice(deviceId);
        final device = deviceList.firstWhere((d) => d.id == deviceId);
        connectedNotifier.addDevice(device.copyWith(isConnected: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to ${device.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect $deviceId: $e')),
          );
        }
      }
    });

    await Future.wait(futures);
  }

  Future<void> _startSession() async {
    if (_isStartingSession) return;
    setState(() => _isStartingSession = true);

    final selectedDeviceIds = ref.read(selectedDevicesProvider);
    final ouraAuth = ref.read(ouraAuthStateProvider);
    final ouraConnected =
        ouraAuth.status == OuraConnectionStatus.connected;
    final raybanSelected = ref.read(raybanSelectedProvider);

    if (selectedDeviceIds.isEmpty && !ouraConnected && raybanSelected.isEmpty) {
      if (mounted) setState(() => _isStartingSession = false);
      return;
    }

    if (selectedDeviceIds.isNotEmpty) {
      final connectedDevices = ref.read(connectedDevicesProvider);
      final notConnected = selectedDeviceIds
          .where((id) => !connectedDevices.containsKey(id));

      if (notConnected.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please connect all selected Muse devices before starting.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        if (mounted) setState(() => _isStartingSession = false);
        return;
      }
    }

    if (_isScanning) {
      setState(() => _isScanning = false);
      ref.read(museServiceProvider).stopScanning();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SessionGatewayScreen(),
      ),
    );
    if (mounted) setState(() => _isStartingSession = false);
  }

  void _viewPastRecordings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PastRecordingsScreen(),
      ),
    );
  }

  Future<void> _recoverLostFiles() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanning for lost files...')),
    );

    final recovered = await FileStorageHelper.recoverLostFiles();

    if (!mounted) return;

    if (recovered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lost files found.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recovered ${recovered.length} file(s)!'),
          action: SnackBarAction(
            label: 'View',
            onPressed: _viewPastRecordings,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    ref.read(museServiceProvider).stopScanning();
    _tabController.dispose();
    _ouraTokenController.dispose();
    super.dispose();
  }
}
