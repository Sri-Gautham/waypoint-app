import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_colors.dart';
import '../home/main_shell.dart';
import 'onboarding_flow.dart';

/// Shown on relaunch when a session was persisted for a user who opted
/// into Face ID (profiles.face_id_enabled). Confirms biometrics before
/// handing back the already-signed-in session.
class FaceIdGateScreen extends StatefulWidget {
  const FaceIdGateScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<FaceIdGateScreen> createState() => _FaceIdGateScreenState();
}

class _FaceIdGateScreenState extends State<FaceIdGateScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await BiometricService.instance.authenticate(reason: 'Unlock Waypoint');
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(data: widget.data)),
      );
      return;
    }
    setState(() {
      _busy = false;
      _failed = true;
    });
  }

  Future<void> _signOutInstead() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: context.colors.accentTint, shape: BoxShape.circle),
                child: Icon(Icons.face_retouching_natural_rounded, color: context.colors.accent, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome back${widget.data.firstName.isEmpty ? '' : ', ${widget.data.firstName}'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                _failed ? "Couldn't verify — try again." : 'Confirm with Face ID to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _failed ? Colors.red : context.colors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _authenticate,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Try again'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _busy ? null : _signOutInstead,
                  child: Text('Sign in differently', style: TextStyle(color: context.colors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
