import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/oura_provider.dart';
import '../providers/rayban_provider.dart';
import '../../domain/models/session_config.dart';
import '../../domain/models/oura_data.dart';
import '../widgets/hsi_indicator.dart';
import '../widgets/eeg_chart.dart';
import '../widgets/fnirs_chart.dart';
import '../widgets/imu_chart.dart';
import '../widgets/band_power_chart.dart';
import '../widgets/arousal_index_widget.dart';
import '../../data/muse/osc_service.dart';
import '../../data/storage/oura_csv_writer.dart';
import '../providers/osc_streaming_provider.dart';
import 'post_session_screen.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen>
    with WidgetsBindingObserver {
  Offset _previewOffset = const Offset(12, 12);
  bool _previewCollapsed = true;
  bool _videoSavedOnBackground = false;
  OuraDailySummary? _ouraSummary;
  bool _ouraLoading = false;
  String? _ouraError;
  DateTime? _ouraLastFetched;
  File? _ouraCsvFile;
  Timer? _ouraPollTimer;
  bool _isOuraFetchInFlight = false;
  DateTime _ouraViewDate = DateTime.now();
  final List<OuraHeartRate> _heartRateHistory = [];
  final List<OuraHrvSample> _hrvHistory = [];
  bool _recordingReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _ouraPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final config = ref.read(sessionConfigProvider);
    if (config == null || !config.recordVideo) return;

    final cameraService = ref.read(cameraRecordingServiceProvider);

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (cameraService.isRecording && !_videoSavedOnBackground) {
        _videoSavedOnBackground = true;
        cameraService.stopRecording().then((savedFile) {
          if (savedFile != null) {
            ref.read(recordingManagerProvider).setVideoFile(savedFile);
          }
        });
      }
    }
  }

  Future<void> _startRecording() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final recordingManager = ref.read(recordingManagerProvider);
    try {
      await recordingManager.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }

    if (!mounted) return;
    setState(() => _recordingReady = true);

    final config = ref.read(sessionConfigProvider);
    if (config != null && config.includeOura) {
      _fetchOuraData();
      _startOuraPolling();
    }
  }

  void _startOuraPolling() {
    _ouraPollTimer?.cancel();
    _ouraPollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _fetchOuraData(silent: true));
  }

  void _mergeOuraSamples(OuraDailySummary summary) {
    final existingHrTs =
        _heartRateHistory.map((s) => s.timestamp.millisecondsSinceEpoch).toSet();
    for (final sample in summary.heartRates) {
      final ts = sample.timestamp.millisecondsSinceEpoch;
      if (!existingHrTs.contains(ts)) {
        _heartRateHistory.add(sample);
      }
    }
    _heartRateHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (_heartRateHistory.length > 300) {
      _heartRateHistory.removeRange(0, _heartRateHistory.length - 300);
    }

    final existingHrvTs =
        _hrvHistory.map((s) => s.timestamp.millisecondsSinceEpoch).toSet();
    for (final sample in summary.hrvSamples) {
      final ts = sample.timestamp.millisecondsSinceEpoch;
      if (!existingHrvTs.contains(ts)) {
        _hrvHistory.add(sample);
      }
    }
    _hrvHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (_hrvHistory.length > 300) {
      _hrvHistory.removeRange(0, _hrvHistory.length - 300);
    }
  }

  Future<void> _fetchOuraData({bool silent = false}) async {
    if (_isOuraFetchInFlight) return;
    _isOuraFetchInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _ouraLoading = true;
        _ouraError = null;
      });
    }

    try {
      final ouraService = ref.read(ouraServiceProvider);
      final summary = await ouraService.getDailySummary(DateTime.now());
      final writer = OuraCsvWriter();
      final csvFile = await writer.writeSession(
        summary,
        sessionStartTime:
            ref.read(recordingManagerProvider).sessionStartTime,
      );

      if (mounted) {
        _mergeOuraSamples(summary);
        setState(() {
          _ouraSummary = summary;
          _ouraLoading = false;
          _ouraLastFetched = DateTime.now();
          _ouraCsvFile = csvFile;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ouraError = e.toString();
          _ouraLoading = false;
        });
      }
    } finally {
      _isOuraFetchInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(sessionConfigProvider);

    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(child: Text('No session configured')),
      );
    }

    if (!_recordingReady) {
      return Scaffold(
        appBar: AppBar(title: Text(config.sessionName)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Starting session...'),
            ],
          ),
        ),
      );
    }

    final recordingState = ref.watch(recordingStateProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider);

    if (config.hasMuseDevices) {
      ref.watch(oscStreamingManagerProvider);
    }
    final isOscStreaming =
        config.hasMuseDevices
            ? ref.watch(isOscStreamingProvider)
            : false;

    final museDeviceIds = config.selectedDeviceIds;
    final hasOura = config.includeOura;
    final hasRayBan = config.includeRayBan;

    final tabCount = museDeviceIds.length +
        (hasOura ? 1 : 0) +
        (hasRayBan ? 1 : 0);

    if (tabCount == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(child: Text('No devices configured')),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await _showStopConfirmation();
        return shouldPop ?? false;
      },
      child: DefaultTabController(
        length: tabCount,
        child: Scaffold(
          appBar: AppBar(
            title: Text(config.sessionName),
            bottom: tabCount > 1
                ? TabBar(
                    isScrollable: tabCount > 3,
                    tabs: [
                      ...museDeviceIds.map((id) {
                        final deviceNames =
                            ref.watch(deviceNamesProvider);
                        final displayName = deviceNames[id] ??
                            connectedDevices[id]?.name ??
                            id;
                        return Tab(text: displayName);
                      }),
                      if (hasOura) const Tab(text: 'Oura Ring'),
                      if (hasRayBan) const Tab(text: 'Ray-Ban'),
                    ],
                  )
                : null,
            actions: [
              if (config.hasMuseDevices)
                IconButton(
                  icon: Icon(
                    isOscStreaming
                        ? Icons.wifi_tethering
                        : Icons.wifi_tethering_off,
                    color: isOscStreaming ? Colors.greenAccent : null,
                  ),
                  onPressed: () => _showOscSettings(context),
                  tooltip: 'OSC Streaming Settings',
                ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: recordingState == RecordingState.recording
                    ? Colors.red.shade700
                    : Colors.grey,
                child: Row(
                  children: [
                    Icon(
                      recordingState == RecordingState.recording
                          ? Icons.fiber_manual_record
                          : Icons.pause,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      recordingState == RecordingState.recording
                          ? 'RECORDING'
                          : 'PAUSED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (config.recordVideo) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.videocam,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      const Text(
                        'VIDEO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Icon(Icons.timer,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    _buildTimer(),
                  ],
                ),
              ),

              ...museDeviceIds.map((deviceId) =>
                  _StreamKeeper(deviceId: deviceId)),

              Expanded(
                child: Stack(
                  children: [
                    tabCount > 1
                        ? TabBarView(
                            children: [
                              ...museDeviceIds.map((deviceId) =>
                                  _buildMuseDeviceView(deviceId)),
                              if (hasOura) _buildOuraView(),
                              if (hasRayBan)
                                _buildRayBanView(config.raybanMediaPaths),
                            ],
                          )
                        : hasRayBan && museDeviceIds.isEmpty && !hasOura
                            ? _buildRayBanView(config.raybanMediaPaths)
                            : hasOura && museDeviceIds.isEmpty
                                ? _buildOuraView()
                                : _buildMuseDeviceView(
                                    museDeviceIds.first),
                    if (config.recordVideo) _buildCameraPreview(),
                  ],
                ),
              ),

              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final recordingManager = ref.read(recordingManagerProvider);
        final elapsed = recordingManager.elapsedSeconds;
        final minutes = elapsed ~/ 60;
        final seconds = elapsed % 60;
        return Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Muse device view (unchanged from original)
  // ---------------------------------------------------------------------------

  Widget _buildMuseDeviceView(String deviceId) {
    final connectedDevices = ref.watch(connectedDevicesProvider);
    final device = connectedDevices[deviceId];

    if (device == null) {
      return const Center(child: Text('Muse device not connected'));
    }

    final museService = ref.read(museServiceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              HsiIndicator(
                tp9: device.tp9Hsi,
                af7: device.af7Hsi,
                af8: device.af8Hsi,
                tp10: device.tp10Hsi,
              ),
              Column(
                children: [
                  const Icon(Icons.battery_std, size: 48),
                  Text(
                    '${device.batteryPercent}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('EEG Raw Data',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: EegChart(
              dataStream: museService.subscribeToEeg(deviceId),
            ),
          ),
          const SizedBox(height: 24),
          Text('Band Powers',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: BandPowerChart(
              dataStream: museService.subscribeToBandPowers(deviceId),
            ),
          ),
          const SizedBox(height: 24),
          Text('fNIRS (Oxygenation)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: FnirsChart(
              dataStream: museService.subscribeToFnirs(deviceId),
            ),
          ),
          const SizedBox(height: 24),
          Text('Arousal Index',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ArousalIndexWidget(deviceId: deviceId),
          const SizedBox(height: 24),
          Text('IMU (Motion)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ImuChart(
            dataStream: museService.subscribeToImu(deviceId),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Oura view
  // ---------------------------------------------------------------------------

  Widget _buildOuraView() {
    final selectedDate = DateTime(
      _ouraViewDate.year,
      _ouraViewDate.month,
      _ouraViewDate.day,
    );
    final viewingToday = _isSameDay(selectedDate, DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Oura Data',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: viewingToday
                    ? null
                    : () => setState(() => _ouraViewDate = DateTime.now()),
                child: const Text('Today'),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _ouraViewDate =
                        selectedDate.subtract(const Duration(days: 1));
                  });
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
                onPressed: selectedDate
                        .isBefore(DateTime.now().subtract(const Duration(days: 1)))
                    ? () {
                        setState(() {
                          _ouraViewDate =
                              selectedDate.add(const Duration(days: 1));
                        });
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next day',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (viewingToday)
            _buildCurrentDayOuraContent()
          else
            _buildHistoricalOuraContent(selectedDate),
        ],
      ),
    );
  }

  Widget _buildCurrentDayOuraContent() {
    if (_ouraLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching Oura Ring data...'),
            ],
          ),
        ),
      );
    }

    if (_ouraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to fetch Oura data',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_ouraError!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _fetchOuraData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _ouraSummary;
    if (summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ring_volume, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No Oura data available yet'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _fetchOuraData,
              icon: const Icon(Icons.refresh),
              label: const Text('Fetch Data'),
            ),
          ],
        ),
      );
    }

    final heartRates =
        _heartRateHistory.isNotEmpty ? _heartRateHistory : summary.heartRates;
    final hrvSamples =
        _hrvHistory.isNotEmpty ? _hrvHistory : summary.hrvSamples;

    return _buildOuraSummaryCards(
      summary: summary,
      heartRates: heartRates,
      hrvSamples: hrvSamples,
      showLiveBadge: true,
      showCsvNotice: true,
      onRefresh: _fetchOuraData,
      lastFetched: _ouraLastFetched,
    );
  }

  Widget _buildHistoricalOuraContent(DateTime selectedDate) {
    final summaryAsync = ref.watch(ouraDailySummaryProvider(selectedDate));
    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Failed to load day: $error',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ),
      data: (summary) => _buildOuraSummaryCards(
        summary: summary,
        heartRates: summary.heartRates,
        hrvSamples: summary.hrvSamples,
        showLiveBadge: false,
        showCsvNotice: false,
        onRefresh: () => ref.invalidate(ouraDailySummaryProvider(selectedDate)),
      ),
    );
  }

  Widget _buildOuraSummaryCards({
    required OuraDailySummary summary,
    required List<OuraHeartRate> heartRates,
    required List<OuraHrvSample> hrvSamples,
    required bool showLiveBadge,
    required bool showCsvNotice,
    required VoidCallback onRefresh,
    DateTime? lastFetched,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${showLiveBadge ? "Today" : "History"} — ${DateFormat('MMM d, yyyy').format(summary.day)}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh selected day',
            ),
          ],
        ),
        if (lastFetched != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Fetched from Oura Cloud at ${DateFormat('h:mm:ss a').format(lastFetched)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
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
                  showLiveBadge
                      ? 'Data syncs from ring → Oura app → cloud. Open the Oura app to push newer readings.'
                      : 'Viewing historical cloud-synced Oura data for this date.',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
        if (summary.readiness != null) ...[
          _ouraReadinessCard(summary.readiness!),
          const SizedBox(height: 12),
        ],
        if (summary.stress != null) ...[
          _ouraStressCard(summary.stress!),
          const SizedBox(height: 12),
        ],
        if (summary.sleep != null) ...[
          _ouraSleepCard(summary.sleep!),
          const SizedBox(height: 12),
        ],
        if (summary.activity != null) ...[
          _ouraActivityCard(summary.activity!),
          const SizedBox(height: 12),
        ],
        if (heartRates.isNotEmpty) ...[
          _ouraHeartRateCard(heartRates),
          const SizedBox(height: 12),
          _ouraLineChartCard(
            title: 'Heart Rate Trend (Cloud-synced)',
            points: heartRates
                .take(120)
                .toList()
                .asMap()
                .entries
                .map((entry) =>
                    FlSpot(entry.key.toDouble(), entry.value.bpm.toDouble()))
                .toList(),
            color: Colors.red.shade400,
            yLabel: 'BPM',
          ),
          const SizedBox(height: 12),
        ],
        if (hrvSamples.isNotEmpty) ...[
          _ouraHrvCard(hrvSamples),
          const SizedBox(height: 12),
          _ouraLineChartCard(
            title: 'HRV Trend (Cloud-synced)',
            points: hrvSamples
                .take(120)
                .toList()
                .asMap()
                .entries
                .map((entry) => FlSpot(entry.key.toDouble(), entry.value.rmssd))
                .toList(),
            color: Colors.purple.shade400,
            yLabel: 'RMSSD',
          ),
          const SizedBox(height: 12),
        ],
        if (summary.sleep == null &&
            summary.activity == null &&
            summary.readiness == null &&
            summary.stress == null &&
            summary.heartRates.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No Oura data available for this day yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        if (showCsvNotice && _ouraCsvFile != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.save, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Oura data saved to CSV — will be included when you share session files.',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _ouraReadinessCard(OuraReadinessData readiness) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.teal.shade400),
                const SizedBox(width: 8),
                const Text('Readiness',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                  '${readiness.score}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: readiness.score >= 70
                        ? Colors.green
                        : readiness.score >= 50
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (readiness.restingHeartRate != null)
              _ouraMetricRow('Resting HR', '${readiness.restingHeartRate}'),
            if (readiness.hrvBalance != null)
              _ouraMetricRow('HRV Balance', '${readiness.hrvBalance}'),
            if (readiness.bodyTemperature != null)
              _ouraMetricRow('Body Temperature', '${readiness.bodyTemperature}'),
            if (readiness.previousDayActivity != null)
              _ouraMetricRow('Prev Day Activity', '${readiness.previousDayActivity}'),
            if (readiness.sleepBalance != null)
              _ouraMetricRow('Sleep Balance', '${readiness.sleepBalance}'),
            if (readiness.previousNight != null)
              _ouraMetricRow('Previous Night', '${readiness.previousNight}'),
            if (readiness.recoveryIndex != null)
              _ouraMetricRow('Recovery Index', '${readiness.recoveryIndex}'),
          ],
        ),
      ),
    );
  }

  Widget _ouraStressCard(OuraStressData stress) {
    Color summaryColor;
    IconData summaryIcon;
    switch (stress.daySummary) {
      case 'restored':
        summaryColor = Colors.green;
        summaryIcon = Icons.self_improvement;
        break;
      case 'stressful':
        summaryColor = Colors.red;
        summaryIcon = Icons.warning_amber_rounded;
        break;
      default:
        summaryColor = Colors.amber.shade700;
        summaryIcon = Icons.balance;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(summaryIcon, color: summaryColor),
                const SizedBox(width: 8),
                const Text('Stress',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: summaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stress.daySummary.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            _ouraMetricRow('Stress (high)',
                '${stress.stressHighMinutes.toStringAsFixed(0)} min'),
            _ouraMetricRow('Recovery (high)',
                '${stress.recoveryHighMinutes.toStringAsFixed(0)} min'),
          ],
        ),
      ),
    );
  }

  Widget _ouraSleepCard(OuraSleepData sleep) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nightlight_round,
                    color: Colors.indigo.shade400),
                const SizedBox(width: 8),
                const Text('Sleep',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                  '${sleep.score}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: sleep.score >= 70
                        ? Colors.green
                        : sleep.score >= 50
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(),
            _ouraMetricRow('Total Sleep',
                _formatDuration(sleep.totalSleepSeconds)),
            _ouraMetricRow(
                'REM', _formatDuration(sleep.remSleepSeconds)),
            _ouraMetricRow(
                'Deep', _formatDuration(sleep.deepSleepSeconds)),
            _ouraMetricRow(
                'Light', _formatDuration(sleep.lightSleepSeconds)),
            if (sleep.restingHeartRate > 0)
              _ouraMetricRow('Resting HR',
                  '${sleep.restingHeartRate} bpm'),
          ],
        ),
      ),
    );
  }

  Widget _ouraActivityCard(OuraActivityData activity) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_run,
                    color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text('Activity',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                  '${activity.score}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: activity.score >= 70
                        ? Colors.green
                        : activity.score >= 50
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(),
            _ouraMetricRow(
                'Steps', NumberFormat('#,###').format(activity.steps)),
            _ouraMetricRow('Active Calories',
                '${activity.activeCalories} kcal'),
            _ouraMetricRow('Total Calories',
                '${activity.totalCalories} kcal'),
          ],
        ),
      ),
    );
  }

  Widget _ouraHeartRateCard(List<OuraHeartRate> heartRates) {
    final latest = heartRates.last;
    final avgBpm = heartRates.fold<int>(0, (sum, hr) => sum + hr.bpm) ~/
        heartRates.length;
    final minBpm = heartRates
        .map((hr) => hr.bpm)
        .reduce((a, b) => a < b ? a : b);
    final maxBpm = heartRates
        .map((hr) => hr.bpm)
        .reduce((a, b) => a > b ? a : b);
    final timeFmt = DateFormat('h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red.shade400),
                const SizedBox(width: 8),
                const Text('Heart Rate',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                  '${latest.bpm}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                  ),
                ),
                const Text(' bpm'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                'Last reading at ${timeFmt.format(latest.timestamp.toLocal())} (${latest.source})',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            const Divider(),
            _ouraMetricRow('Average', '$avgBpm bpm'),
            _ouraMetricRow('Min', '$minBpm bpm'),
            _ouraMetricRow('Max', '$maxBpm bpm'),
            _ouraMetricRow(
                'Samples', '${heartRates.length} readings'),
            _ouraMetricRow('First reading',
                timeFmt.format(heartRates.first.timestamp.toLocal())),
            _ouraMetricRow('Last reading',
                timeFmt.format(latest.timestamp.toLocal())),
          ],
        ),
      ),
    );
  }

  Widget _ouraHrvCard(List<OuraHrvSample> hrvSamples) {
    final latest = hrvSamples.last;
    final avgHrv =
        hrvSamples.fold<double>(0, (sum, s) => sum + s.rmssd) /
            hrvSamples.length;
    final timeFmt = DateFormat('h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.purple.shade400),
                const SizedBox(width: 8),
                const Text('HRV',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                  latest.rmssd.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade400,
                  ),
                ),
                const Text(' ms'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                'Last reading at ${timeFmt.format(latest.timestamp.toLocal())}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            const Divider(),
            _ouraMetricRow(
                'Average RMSSD', '${avgHrv.toStringAsFixed(1)} ms'),
            _ouraMetricRow(
                'Samples', '${hrvSamples.length} readings'),
          ],
        ),
      ),
    );
  }

  Widget _ouraLineChartCard({
    required String title,
    required List<FlSpot> points,
    required Color color,
    required String yLabel,
  }) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }

    final ys = points.map((p) => p.y).toList();
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY) * 0.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  minY: minY - padding,
                  maxY: maxY + padding,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: ((maxY - minY) / 4).abs() < 1
                        ? 1
                        : ((maxY - minY) / 4),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        yLabel,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      sideTitles: const SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      isCurved: true,
                      color: color,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Most recent cloud-synced points',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ouraMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ---------------------------------------------------------------------------
  // Ray-Ban media view
  // ---------------------------------------------------------------------------

  Widget _buildRayBanView(List<String> mediaPaths) {
    if (mediaPaths.isEmpty) {
      return const Center(child: Text('No Ray-Ban media attached'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: Colors.blue.shade400),
                  const SizedBox(width: 8),
                  const Text(
                    'Ray-Ban Meta',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    '${mediaPaths.length} files',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mediaPaths.map((path) {
              final filename = path.split('/').last;
              final ext = filename.split('.').last.toLowerCase();
              final isVideo = {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(ext);

              return SizedBox(
                width: (MediaQuery.of(context).size.width - 40) / 3,
                height: 120,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: isVideo
                      ? Container(
                          color: Colors.grey[900],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_circle_fill,
                                  size: 32, color: Colors.white70),
                              const SizedBox(height: 4),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  filename,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 9),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image,
                                    size: 24, color: Colors.grey),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  child: Text(
                                    filename,
                                    style: const TextStyle(fontSize: 8),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(raybanScannedMediaProvider.notifier).pickManually();
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add More Media'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '—';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  // ---------------------------------------------------------------------------
  // Camera preview (unchanged)
  // ---------------------------------------------------------------------------

  Widget _buildCameraPreview() {
    final cameraService = ref.read(cameraRecordingServiceProvider);
    final controller = cameraService.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final isLandscape = cameraService.isLandscape;
    final expandedWidth = isLandscape ? 192.0 : 120.0;
    final expandedHeight = isLandscape ? 120.0 : 160.0;

    return Positioned(
      left: _previewOffset.dx,
      top: _previewOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _previewOffset += details.delta;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.black87,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8)),
              child: InkWell(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8)),
                onTap: () => setState(
                    () => _previewCollapsed = !_previewCollapsed),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam,
                          color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _previewCollapsed ? 'Show' : 'Hide',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                      Icon(
                        _previewCollapsed
                            ? Icons.expand_more
                            : Icons.expand_less,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_previewCollapsed)
              GestureDetector(
                onTap: () => _showFullScreenPreview(controller),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: Container(
                    width: expandedWidth,
                    height: expandedHeight,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.red, width: 2),
                    ),
                    child: CameraPreview(controller),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenPreview(CameraController controller) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _FullScreenCameraPreview(controller: controller),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom controls
  // ---------------------------------------------------------------------------

  Widget _buildBottomControls() {
    final recordingState = ref.watch(recordingStateProvider);
    final isPaused = recordingState == RecordingState.paused;

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
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _togglePauseResume,
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(isPaused ? 'Resume' : 'Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPaused ? Colors.green : Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _addTrigger,
              icon: const Icon(Icons.flag),
              label: const Text('Add Marker'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: const Text('Stop & Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addTrigger() {
    final recordingManager = ref.read(recordingManagerProvider);
    recordingManager.addTrigger();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marker added'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _togglePauseResume() async {
    final recordingManager = ref.read(recordingManagerProvider);
    final recordingState = ref.read(recordingStateProvider);

    try {
      if (recordingState == RecordingState.paused) {
        await recordingManager.resumeRecording();
      } else {
        await recordingManager.pauseRecording();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pause/Resume failed: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    final recordingManager = ref.read(recordingManagerProvider);
    await recordingManager.stopRecording();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PostSessionScreen(),
        ),
      );
    }
  }

  Future<bool?> _showStopConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text(
          'Are you sure you want to stop recording? This will save the session data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Recording'),
          ),
          TextButton(
            onPressed: () async {
              await _stopRecording();
              if (mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Stop & Save'),
          ),
        ],
      ),
    );
  }

  void _showOscSettings(BuildContext context) {
    final ipController =
        TextEditingController(text: ref.read(oscTargetIpProvider));
    final ports = ref.read(oscTargetPortsProvider);
    final portController =
        TextEditingController(text: ports.join(', '));
    final config = ref.read(sessionConfigProvider);

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isStreaming = ref.watch(isOscStreamingProvider);
          final format = ref.watch(oscOutputFormatProvider);
          final connectedDevices =
              ref.read(connectedDevicesProvider);
          final deviceIds = config?.selectedDeviceIds ?? [];
          final currentPorts = ref.watch(oscTargetPortsProvider);

          return AlertDialog(
            title: const Text('OSC Streaming Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stream Band Powers to VR Headset via Wi-Fi.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (deviceIds.length >= 2) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Device Mapping:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          for (int i = 0;
                              i < deviceIds.length && i < 2;
                              i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 2),
                              child: Text(
                                '• ${connectedDevices[deviceIds[i]]?.name ?? deviceIds[i]} → Person ${i + 1} (Port ${(i < currentPorts.length) ? currentPorts[i] : 5000}${format == OscOutputFormat.muselog ? ', /person${i + 1}/eeg' : ', /muse/elements/* + /muse/eeg'})',
                                style: const TextStyle(
                                    fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<OscOutputFormat>(
                    value: format,
                    decoration: const InputDecoration(
                      labelText: 'OSC Format',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: OscOutputFormat.snowballArcade,
                        child: Text(
                            'SnowballArcade (/muse/elements/* + /muse/eeg)'),
                      ),
                      DropdownMenuItem(
                        value: OscOutputFormat.muselog,
                        child: Text(
                            'MuseLog legacy (/person{n}/eeg)'),
                      ),
                    ],
                    onChanged: isStreaming
                        ? null
                        : (value) {
                            if (value != null) {
                              ref
                                  .read(oscOutputFormatProvider
                                      .notifier)
                                  .state = value;
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ipController,
                    decoration: const InputDecoration(
                      labelText: 'Target IP Address',
                      hintText: 'e.g. 192.168.1.100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    enabled: !isStreaming,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: portController,
                    decoration: const InputDecoration(
                      labelText:
                          'Target Ports (comma separated)',
                      hintText: '5000, 5001',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    enabled: !isStreaming,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (isStreaming) {
                    ref
                        .read(isOscStreamingProvider.notifier)
                        .state = false;
                  } else {
                    final targetIp =
                        ipController.text.trim();
                    if (targetIp.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please enter a target IP address.')),
                      );
                      return;
                    }

                    ref
                        .read(oscTargetIpProvider.notifier)
                        .state = targetIp;

                    final portString = portController.text;
                    final portList = portString
                        .split(',')
                        .map((s) => int.tryParse(s.trim()))
                        .where((p) => p != null)
                        .cast<int>()
                        .toList();

                    if (portList.isEmpty) {
                      portList.add(5000);
                    }

                    ref
                        .read(oscTargetPortsProvider.notifier)
                        .state = portList;
                    ref
                        .read(isOscStreamingProvider.notifier)
                        .state = true;
                    ref
                        .read(oscStreamingManagerProvider)
                        .refreshSubscriptions();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'OSC Streaming Started (${format == OscOutputFormat.snowballArcade ? 'SnowballArcade' : 'MuseLog'} format)',
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isStreaming ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(isStreaming
                    ? Icons.stop
                    : Icons.play_arrow),
                label: Text(isStreaming
                    ? 'Stop Streaming'
                    : 'Start Streaming'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StreamKeeper extends ConsumerStatefulWidget {
  final String deviceId;

  const _StreamKeeper({required this.deviceId});

  @override
  ConsumerState<_StreamKeeper> createState() => _StreamKeeperState();
}

class _StreamKeeperState extends ConsumerState<_StreamKeeper> {
  StreamSubscription? _batterySub;
  StreamSubscription? _hsiSub;

  @override
  void initState() {
    super.initState();
    final museService = ref.read(museServiceProvider);

    _batterySub = museService.subscribeToBattery(widget.deviceId).listen(
      (battery) {
        ref
            .read(connectedDevicesProvider.notifier)
            .updateBattery(widget.deviceId, battery);
      },
      onError: (_) {},
    );

    _hsiSub = museService.subscribeToHsi(widget.deviceId).listen(
      (hsiMap) {
        ref
            .read(connectedDevicesProvider.notifier)
            .updateHsi(widget.deviceId, hsiMap);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _batterySub?.cancel();
    _hsiSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _FullScreenCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _FullScreenCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: CameraPreview(controller)),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: const Center(
                child: Text(
                  'Tap anywhere to close',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
