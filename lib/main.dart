import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_colors.dart';
import 'presentation/screens/healthlog_dashboard_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: HealthLogProtocolApp(),
    ),
  );
}

class HealthLogProtocolApp extends StatelessWidget {
  const HealthLogProtocolApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.buildTheme();
    return MaterialApp(
      title: 'HealthLog Protocol',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const HealthLogDashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
