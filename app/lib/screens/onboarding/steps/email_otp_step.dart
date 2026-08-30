import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/onboarding_data.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/step_header.dart';

/// Verifies the code [EmailSignInStep] sent, then completes sign-in the
/// same way Apple/Google do (populate [data] from the account's profile,
/// call [onSignedIn]) and pops back out to the base onboarding flow.
class EmailOtpStep extends StatefulWidget {
  const EmailOtpStep({super.key, required this.email, required this.data, required this.onSignedIn});

  final String email;
  final OnboardingData data;
  final void Function({required bool isNewUser}) onSignedIn;

  @override
  State<EmailOtpStep> createState() => _EmailOtpStepState();
}

class _EmailOtpStepState extends State<EmailOtpStep> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final result = await AuthService.instance.verifyEmailOtp(email: widget.email, token: code);
      final loaded = await AuthService.instance.loadProfile();
      widget.data
        ..firstName = loaded.firstName
        ..lastName = loaded.lastName
        ..email = loaded.email
        ..phone = loaded.phone
        ..street = loaded.street
        ..apt = loaded.apt
        ..city = loaded.city
        ..state = loaded.state
        ..zip = loaded.zip;
      if (!mounted) return;
      widget.onSignedIn(isNewUser: result.isNewUser);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'That code is invalid or expired. Try again or resend.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await AuthService.instance.sendEmailOtp(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't resend the code. Try again.");
    } finally {
      if (mounted) setState(() => _resending = false);
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
                'Enter your code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${widget.email}.',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
                decoration: const InputDecoration(counterText: '', hintText: '000000'),
                onSubmitted: (_) => _verify(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? 'Resending…' : 'Resend code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
