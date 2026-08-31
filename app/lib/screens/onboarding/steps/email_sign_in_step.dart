import 'package:flutter/material.dart';

import '../../../models/onboarding_data.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/step_header.dart';
import 'email_otp_step.dart';

/// Entry point for passwordless email sign-in: type an email, get sent a
/// 6-digit code. Reached by pushing on top of [SignInStep] (not part of
/// OnboardingFlow's own step switch, since it's a self-contained side
/// path — [EmailOtpStep] pops back out to the base flow once it succeeds).
class EmailSignInStep extends StatefulWidget {
  const EmailSignInStep({super.key, required this.data, required this.onSignedIn});

  final OnboardingData data;
  final void Function({required bool isNewUser}) onSignedIn;

  @override
  State<EmailSignInStep> createState() => _EmailSignInStepState();
}

class _EmailSignInStepState extends State<EmailSignInStep> {
  final _emailController = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _validEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!_validEmail) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AuthService.instance.sendEmailOtp(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EmailOtpStep(email: email, data: widget.data, onSignedIn: widget.onSignedIn)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't send a code. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              StepHeader(step: 1, total: 1, onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 28),
              Text(
                'Sign in with email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                "We'll send a 6-digit code — no password needed.",
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendCode(),
                decoration: const InputDecoration(labelText: 'Email', hintText: 'jamie@email.com'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendCode,
                  child: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
