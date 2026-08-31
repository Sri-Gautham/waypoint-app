import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/home/main_shell.dart';
import 'screens/onboarding/face_id_gate_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/auth_service.dart';
import 'state/app_data.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
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
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _StartupGate(),
      ),
    );
  }
}

/// Routes a cold launch to the right starting screen: signed out ->
/// onboarding; signed in without Face ID -> straight to Home; signed in
/// with Face ID enabled -> the biometric gate first.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<Widget> _destination = _resolve();

  Future<Widget> _resolve() async {
    if (!AuthService.instance.isSignedIn) return const OnboardingFlow();
    try {
      final profile = await AuthService.instance.loadProfile();
      return profile.faceIdEnabled ? FaceIdGateScreen(data: profile) : MainShell(data: profile);
    } catch (_) {
      return const OnboardingFlow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data!;
      },
    );
  }
}
