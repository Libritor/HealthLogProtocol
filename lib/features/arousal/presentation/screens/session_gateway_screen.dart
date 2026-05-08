import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../presentation/screens/recording_config_screen.dart';
import '../../../../presentation/providers/device_provider.dart';
import '../../../../presentation/providers/oura_provider.dart';
import '../../../../data/ai/meditation_ai_service.dart';
import 'arousal_live_session_screen.dart';

/// Session Gateway Screen - Non-destructive hook point
/// Allows user to choose between standard data collection or arousal analysis
class SessionGatewayScreen extends ConsumerWidget {
  const SessionGatewayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDevices = ref.watch(selectedDevicesProvider);
    final connectedDevices = ref.watch(connectedDevicesProvider);
    final ouraAuth = ref.watch(ouraAuthStateProvider);
    final hasMuseDevices = selectedDevices.isNotEmpty;
    final hasOura = ouraAuth.status == OuraConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Mode'),
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Choose Session Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecordingConfigScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fiber_manual_record, size: 48),
                  label: const Text(
                    'Data Collection',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton.icon(
                  onPressed: hasMuseDevices
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MeditationGoalScreen(),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.psychology, size: 48),
                  label: const Text(
                    'Arousal Index & AI Mentor',
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.purple.withOpacity(0.3),
                    disabledForegroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              Text(
                'Data Collection: Standard CSV recording and visualization'
                '${hasOura ? " (includes Oura Ring data)" : ""}\n\n'
                'Arousal Index & AI Mentor: AI-guided meditation with real-time brain state feedback'
                '${!hasMuseDevices ? "\n(Requires a connected Muse headband)" : ""}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Goal Selection Screen for meditation
class MeditationGoalScreen extends ConsumerWidget {
  const MeditationGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedDevices = ref.watch(connectedDevicesProvider);
    final selectedDevices = ref.watch(selectedDevicesProvider);
    
    // Get first connected device
    final deviceId = selectedDevices.isNotEmpty 
        ? selectedDevices.first 
        : connectedDevices.keys.isNotEmpty 
            ? connectedDevices.keys.first 
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Goal'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            
            // Header
            const Text(
              'What would you like to achieve?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'The AI mentor will guide you based on your goal',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Focus (Increase Arousal) Card
            _GoalCard(
              goal: MeditationGoal.focus,
              title: 'Focus',
              subtitle: 'Increase alertness & concentration',
              description: 'Boost your arousal index to sharpen your mind, '
                  'enhance productivity, and improve cognitive performance.',
              icon: Icons.bolt,
              color: Colors.orange,
              onTap: deviceId != null ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArousalLiveSessionScreen(
                      deviceId: deviceId,
                      goal: MeditationGoal.focus,
                    ),
                  ),
                );
              } : null,
            ),
            
            const SizedBox(height: 16),
            
            // Calm (Decrease Arousal) Card
            _GoalCard(
              goal: MeditationGoal.calm,
              title: 'Calm Down',
              subtitle: 'Relax & find inner peace',
              description: 'Lower your arousal index to reduce stress, '
                  'promote relaxation, and achieve a peaceful state of mind.',
              icon: Icons.spa,
              color: Colors.blue,
              onTap: deviceId != null ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArousalLiveSessionScreen(
                      deviceId: deviceId,
                      goal: MeditationGoal.calm,
                    ),
                  ),
                );
              } : null,
            ),
            
            const SizedBox(height: 24),
            
            // Device status
            if (deviceId == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No device connected. Please go back and connect a Muse headband.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_connected, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connected: ${connectedDevices[deviceId]?.name ?? deviceId}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final MeditationGoal goal;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _GoalCard({
    required this.goal,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(onTap != null ? 0.1 : 0.05),
                color.withOpacity(onTap != null ? 0.2 : 0.1),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: onTap != null ? color : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: onTap != null ? color : Colors.grey,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: onTap != null 
                                ? color.withOpacity(0.8) 
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: onTap != null ? color : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: onTap != null 
                      ? Colors.grey[700] 
                      : Colors.grey,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              // Goal indicator
              Row(
                children: [
                  Icon(
                    goal == MeditationGoal.focus
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 16,
                    color: onTap != null ? color : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    goal == MeditationGoal.focus
                        ? 'Increase arousal index'
                        : 'Decrease arousal index',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: onTap != null ? color : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
