import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/biometric_service.dart';
import '../../../theme/app_colors.dart';

/// Shown once, right after a first sign-up: "remember me and skip the
/// sign-in screen next time, gated by Face ID". Declining just leaves the
/// session persisted without the biometric gate — this only controls
/// whether relaunch asks for Face ID before landing on Home.
class EnableFaceIdStep extends StatefulWidget {
  const EnableFaceIdStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<EnableFaceIdStep> createState() => _EnableFaceIdStepState();
}

class _EnableFaceIdStepState extends State<EnableFaceIdStep> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    final available = await BiometricService.instance.isAvailable();
    if (!available) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Face ID isn\'t set up on this device.')),
      );
      return;
    }
    final confirmed = await BiometricService.instance.authenticate(reason: 'Enable Face ID for Waypoint');
    if (confirmed) {
      await AuthService.instance.setFaceIdEnabled(true).catchError((_) {});
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            'Enable Face ID?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            "Skip signing in next time — just confirm with Face ID and you're back in your trips.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _enable,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enable Face ID'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : widget.onDone,
              child: Text('Not now', style: TextStyle(color: context.colors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
