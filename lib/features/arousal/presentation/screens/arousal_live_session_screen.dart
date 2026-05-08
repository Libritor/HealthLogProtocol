import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants.dart';
import '../../../../domain/models/arousal_sample.dart';
import '../../../../domain/models/muse_device.dart';
import '../../../../presentation/providers/device_provider.dart';
import '../../../../presentation/providers/arousal_provider.dart';
import '../../../../presentation/providers/recording_provider.dart';
import '../../../../presentation/widgets/arousal_chart.dart';
import '../../../../presentation/widgets/eeg_chart.dart';
import '../../../../presentation/widgets/band_power_chart.dart';
import '../../../../data/ai/meditation_ai_service.dart';

/// Live arousal analysis session screen with AI meditation guide
class ArousalLiveSessionScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final MeditationGoal goal;

  const ArousalLiveSessionScreen({
    super.key,
    required this.deviceId,
    required this.goal,
  });

  @override
  ConsumerState<ArousalLiveSessionScreen> createState() =>
      _ArousalLiveSessionScreenState();
}

class _ArousalLiveSessionScreenState
    extends ConsumerState<ArousalLiveSessionScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _sessionStartTime;
  Duration _sessionDuration = Duration.zero;
  Timer? _timer;
  Timer? _feedbackTimer;
  late AnimationController _recordingAnimationController;

  // AI Meditation Service
  late MeditationAIService _aiService;
  String _currentFeedback = '';
  bool _isAudioEnabled = true;

  // Arousal history for session summary
  final List<ArousalSample> _arousalHistory = [];
  double? _previousArousal;
  double? _startingArousal;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _aiService = MeditationAIService();
    _aiService.initTts();

    _recordingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionDuration = DateTime.now().difference(_sessionStartTime);
        });
      }
    });

    // Start AI feedback timer (every 10 seconds)
    _feedbackTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _generateFeedback();
    });

    // Initial welcome message
    _showWelcomeFeedback();
    
    // Start full data recording (like Data Collection mode)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFullDataRecording();
    });
  }
  
  /// Start full data recording using RecordingManager (same as Data Collection)
  Future<void> _startFullDataRecording() async {
    try {
      // Create session config with all columns selected
      ref.read(sessionConfigProvider.notifier).createConfig(
        selectedDeviceIds: [widget.deviceId],
        selectedColumns: Set.from(AppConstants.csvColumns),
        sessionName: '${widget.goal.displayName}_${DateFormat('yyyy-MM-dd_HHmmss').format(_sessionStartTime)}',
        notes: 'AI Meditation Session - Goal: ${widget.goal.displayName}',
      );
      
      // Start recording
      final recordingManager = ref.read(recordingManagerProvider);
      await recordingManager.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start data recording: $e')),
        );
      }
    }
  }

  void _showWelcomeFeedback() {
    final goalText = widget.goal == MeditationGoal.focus
        ? "Let's build your focus and alertness."
        : "Let's help you relax and find calm.";
    setState(() {
      _currentFeedback = "Welcome to your meditation session. $goalText Take a deep breath and begin.";
    });
    if (_isAudioEnabled) {
      _aiService.speak(_currentFeedback);
    }
  }

  Future<void> _generateFeedback() async {
    if (_arousalHistory.isEmpty) return;

    final latest = _arousalHistory.last;
    final feedback = await _aiService.generateLiveFeedback(
      goal: widget.goal,
      currentArousal: latest.arousalIndex,
      arousalLabel: latest.arousalLabel,
      previousArousal: _previousArousal,
      sessionDuration: _sessionDuration,
    );

    if (feedback.isNotEmpty && mounted) {
      setState(() {
        _currentFeedback = feedback;
      });
      if (_isAudioEnabled) {
        await _aiService.speak(feedback);
      }
    }

    _previousArousal = latest.arousalIndex;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    _recordingAnimationController.dispose();
    _aiService.stopSpeaking();
    _aiService.dispose();
    // Note: Don't stop recording here - it's handled in _showSessionSummary
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _calculateConnectionQuality(Map<String, HsiValue> hsiMap) {
    if (hsiMap.isEmpty) return 0.0;

    final channels = ['TP9', 'AF7', 'AF8', 'TP10'];
    double totalQuality = 0.0;
    int count = 0;

    for (final channel in channels) {
      final hsi = hsiMap[channel];
      if (hsi != null) {
        double quality;
        if (hsi.value == 1) {
          quality = 1.0;
        } else if (hsi.value == 2) {
          quality = 0.5;
        } else {
          quality = 0.0;
        }
        totalQuality += quality;
        count++;
      }
    }

    return count > 0 ? (totalQuality / count) * 100 : 0.0;
  }

  Color _getConnectionColor(double quality) {
    if (quality >= 75) return Colors.green;
    if (quality >= 25) return Colors.orange;
    return Colors.red;
  }

  Color _getArousalLabelColor(String label) {
    switch (label.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getGoalColor() {
    return widget.goal == MeditationGoal.focus ? Colors.orange : Colors.blue;
  }

  Future<void> _handleStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'Would you like to end your meditation session and see your summary?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _showSessionSummary();
    }
  }

  Future<void> _showSessionSummary() async {
    _aiService.stopSpeaking();
    _feedbackTimer?.cancel();
    
    // Stop full data recording
    final recordingManager = ref.read(recordingManagerProvider);
    await recordingManager.stopRecording();

    // Generate session summary
    final arousalValues = _arousalHistory.map((s) => s.arousalIndex).toList();
    final summary = await _aiService.generateSessionSummary(
      goal: widget.goal,
      sessionDuration: _sessionDuration,
      arousalHistory: arousalValues,
      startingArousal: _startingArousal ?? 0.5,
      endingArousal: arousalValues.isNotEmpty ? arousalValues.last : 0.5,
    );

    if (!mounted) return;

    // Show summary dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: _getGoalColor()),
            const SizedBox(width: 8),
            const Text('Session Summary'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Duration',
                      _formatDuration(_sessionDuration),
                      Icons.timer,
                    ),
                    _buildStatItem(
                      'Samples',
                      '${_arousalHistory.length}',
                      Icons.analytics,
                    ),
                    _buildStatItem(
                      'Goal',
                      widget.goal.displayName,
                      widget.goal == MeditationGoal.focus
                          ? Icons.bolt
                          : Icons.spa,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // AI Summary
              Text(
                summary,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 16),
              // Info about full data recording
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Full EEG data has been recorded and saved to your device.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveAndShareSession(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Export Arousal CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Future<void> _saveAndShareSession(BuildContext dialogContext) async {
    try {
      final file = await _saveArousalToCsv();
      
      if (!mounted) return;
      
      Navigator.pop(dialogContext); // Close summary dialog
      
      // Show share options
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Meditation Session - ${DateFormat('yyyy-MM-dd HH:mm').format(_sessionStartTime)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving session: $e')),
        );
      }
    }
  }

  Future<File> _saveArousalToCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'meditation_${DateFormat('yyyyMMdd_HHmmss').format(_sessionStartTime)}.csv';
    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('TIMESTAMP,AROUSAL_INDEX,AROUSAL_LABEL,CONFIDENCE,DECISION_MARGIN,LOW_PROB,MEDIUM_PROB,HIGH_PROB,GOAL,SESSION_TIME_SEC');
    
    // Data rows
    for (int i = 0; i < _arousalHistory.length; i++) {
      final sample = _arousalHistory[i];
      final elapsed = sample.timestamp.difference(_sessionStartTime).inSeconds;
      final probs = sample.clusterProbs ?? {};
      
      buffer.writeln(
        '${sample.timestamp.toIso8601String()},'
        '${sample.arousalIndex.toStringAsFixed(4)},'
        '${sample.arousalLabel},'
        '${sample.confidence.toStringAsFixed(4)},'
        '${(sample.confidenceMargin ?? 0).toStringAsFixed(4)},'
        '${(probs['low'] ?? 0).toStringAsFixed(4)},'
        '${(probs['medium'] ?? 0).toStringAsFixed(4)},'
        '${(probs['high'] ?? 0).toStringAsFixed(4)},'
        '${widget.goal.displayName},'
        '$elapsed'
      );
    }

    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<void> _downloadArousalFile() async {
    try {
      final file = await _saveArousalToCsv();
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Arousal Data - ${DateFormat('yyyy-MM-dd HH:mm').format(_sessionStartTime)}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arousal data exported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    }
  }

  void _onArousalData(ArousalSample sample) {
    _arousalHistory.add(sample);
    _startingArousal ??= sample.arousalIndex;
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = ref.watch(connectedDevicesProvider);
    final device = connectedDevices[widget.deviceId];
    final arousalAsync = ref.watch(arousalStreamProvider(widget.deviceId));
    final batteryAsync = ref.watch(batteryStreamProvider(widget.deviceId));
    final hsiAsync = ref.watch(hsiStreamProvider(widget.deviceId));

    final sessionName = DateFormat('yyyy-MM-dd').format(_sessionStartTime);

    final latestArousal = arousalAsync.valueOrNull;
    final batteryLevel = batteryAsync.valueOrNull ?? 0;
    final hsiMap = hsiAsync.valueOrNull ?? {};
    final connectionQuality = _calculateConnectionQuality(hsiMap);

    // Record arousal data
    arousalAsync.whenData((sample) {
      if (_arousalHistory.isEmpty || 
          _arousalHistory.last.timestamp != sample.timestamp) {
        _onArousalData(sample);
      }
    });

    if (!connectedDevices.containsKey(widget.deviceId)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Device not connected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please connect a device first.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _handleStop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.goal.displayName} Session'),
          automaticallyImplyLeading: false,
          actions: [
            // Audio toggle
            IconButton(
              icon: Icon(_isAudioEnabled ? Icons.volume_up : Icons.volume_off),
              onPressed: () {
                setState(() {
                  _isAudioEnabled = !_isAudioEnabled;
                });
                if (!_isAudioEnabled) {
                  _aiService.stopSpeaking();
                }
              },
              tooltip: _isAudioEnabled ? 'Mute voice' : 'Enable voice',
            ),
            // Download button
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadArousalFile,
              tooltip: 'Download arousal data',
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Goal-colored recording band
              _buildRecordingBand(),

              // Timer and Goal indicator
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getGoalColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.goal == MeditationGoal.focus
                                ? Icons.bolt
                                : Icons.spa,
                            color: _getGoalColor(),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.goal.displayName,
                            style: TextStyle(
                              color: _getGoalColor(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _formatDuration(_sessionDuration),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // AI Feedback Card
              _buildFeedbackCard(),

              // Status bar
              _buildStatusBar(device, connectionQuality, batteryLevel),

              const SizedBox(height: 16),

              // Current state card
              if (latestArousal != null)
                _buildCurrentStateCard(latestArousal)
              else
                _buildWaitingCard(),

              const SizedBox(height: 16),

              // Arousal Chart
              _buildChartCard(arousalAsync),

              const SizedBox(height: 16),
              
              // EEG Raw Data Chart
              _buildEegChartCard(),
              
              const SizedBox(height: 16),
              
              // Band Powers Chart
              _buildBandPowerChartCard(),

              const SizedBox(height: 24),

              // Stop button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _handleStop,
                    icon: const Icon(Icons.stop),
                    label: const Text(
                      'End Session',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingBand() {
    return AnimatedBuilder(
      animation: _recordingAnimationController,
      builder: (context, child) {
        final opacity = 0.5 + (_recordingAnimationController.value * 0.5);
        return Container(
          height: 8,
          color: _getGoalColor().withOpacity(opacity),
        );
      },
    );
  }

  Widget _buildFeedbackCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: _getGoalColor().withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.psychology,
                color: _getGoalColor(),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Guide',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getGoalColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentFeedback.isEmpty
                          ? 'Preparing guidance...'
                          : _currentFeedback,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(
    MuseDevice? device,
    double connectionQuality,
    int batteryLevel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatusItem(
              icon: Icons.bluetooth_connected,
              label: 'Connection',
              value: '${connectionQuality.toStringAsFixed(0)}%',
              color: _getConnectionColor(connectionQuality),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatusItem(
              icon: Icons.battery_charging_full,
              label: 'Battery',
              value: '$batteryLevel%',
              color: batteryLevel > 50
                  ? Colors.green
                  : batteryLevel > 20
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Calibrating...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Collecting EEG data for analysis',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStateCard(ArousalSample sample) {
    final label = sample.arousalLabel.toUpperCase();
    final labelColor = _getArousalLabelColor(sample.arousalLabel);
    final arousalPercent = (sample.arousalIndex * 100).toStringAsFixed(0);

    // Determine if on track for goal
    final isOnTrack = (widget.goal == MeditationGoal.focus && sample.arousalIndex > 0.5) ||
        (widget.goal == MeditationGoal.calm && sample.arousalIndex < 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arousal index display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Arousal Index',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        '$arousalPercent%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: labelColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // On track indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOnTrack
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnTrack ? Icons.check_circle : Icons.adjust,
                              size: 16,
                              color: isOnTrack ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnTrack ? 'On Track' : 'Adjusting',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOnTrack ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Progress bar showing arousal level
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: sample.arousalIndex,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(labelColor),
                ),
              ),

              const SizedBox(height: 8),

              // Scale labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calm',
                    style: TextStyle(fontSize: 12, color: Colors.blue[300]),
                  ),
                  Text(
                    'Medium',
                    style: TextStyle(fontSize: 12, color: Colors.orange[300]),
                  ),
                  Text(
                    'Alert',
                    style: TextStyle(fontSize: 12, color: Colors.red[300]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(AsyncValue<ArousalSample> arousalAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Arousal Over Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Goal indicator
                  Row(
                    children: [
                      Icon(
                        widget.goal == MeditationGoal.focus
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: _getGoalColor(),
                      ),
                      Text(
                        'Target: ${widget.goal == MeditationGoal.focus ? "Higher" : "Lower"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getGoalColor(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              arousalAsync.when(
                data: (sample) => ArousalChart(
                  dataStream: ref.read(arousalStreamProvider(widget.deviceId).stream),
                  windowSeconds: 60,
                ),
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Collecting data...'),
                      ],
                    ),
                  ),
                ),
                error: (err, stack) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('Waiting for EEG data...'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEegChartCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'EEG Raw Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, size: 8, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Recording',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: EegChart(
                  dataStream: ref.read(museServiceProvider).subscribeToEeg(widget.deviceId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBandPowerChartCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Band Powers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, size: 8, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Recording',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BandPowerChart(
                  dataStream: ref.read(museServiceProvider).subscribeToBandPowers(widget.deviceId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
