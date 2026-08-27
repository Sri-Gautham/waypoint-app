import 'package:flutter/material.dart';

import 'screens/onboarding/onboarding_flow.dart';
import 'state/app_data.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const WaypointApp());
}

class WaypointApp extends StatefulWidget {
  const WaypointApp({super.key});

  @override
  State<WaypointApp> createState() => _WaypointAppState();
}

class _WaypointAppState extends State<WaypointApp> {
  final _appData = AppData();

  @override
  void dispose() {
    _appData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sits above MaterialApp's Navigator so every pushed route — not just
    // the initial one — can reach AppData via AppDataScope.of(context).
    return AppDataScope(
      notifier: _appData,
      child: MaterialApp(
        title: 'Waypoint',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const OnboardingFlow(),
      ),
    );
  }
}
