import 'package:flutter/material.dart';

import 'screens/onboarding/onboarding_flow.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const WaypointApp());
}

class WaypointApp extends StatelessWidget {
  const WaypointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waypoint',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const OnboardingFlow(),
    );
  }
}
