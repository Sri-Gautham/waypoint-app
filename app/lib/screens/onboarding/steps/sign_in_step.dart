import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../models/onboarding_data.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import 'email_sign_in_step.dart';

/// The front door: Apple/Google sign-in, no manual form. A first-time
/// sign-in creates the account (via the `handle_new_user` Postgres
/// trigger); a returning account just signs back in.
class SignInStep extends StatefulWidget {
  const SignInStep({super.key, required this.data, required this.onSignedIn});

  final OnboardingData data;
  final void Function({required bool isNewUser}) onSignedIn;

  @override
  State<SignInStep> createState() => _SignInStepState();
}

class _SignInStepState extends State<SignInStep> {
  bool _busy = false;
  String? _error;

  Future<void> _handle(Future<AuthResult> Function() signIn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await signIn();
      if (result.firstName != null && result.firstName!.isNotEmpty) {
        widget.data.firstName = result.firstName!;
      }
      if (result.lastName != null && result.lastName!.isNotEmpty) {
        widget.data.lastName = result.lastName!;
      }
      final loaded = await AuthService.instance.loadProfile();
      if (widget.data.firstName.isEmpty) widget.data.firstName = loaded.firstName;
      if (widget.data.lastName.isEmpty) widget.data.lastName = loaded.lastName;
      widget.data.email = loaded.email;
      widget.data.phone = loaded.phone;
      widget.data.street = loaded.street;
      widget.data.apt = loaded.apt;
      widget.data.city = loaded.city;
      widget.data.state = loaded.state;
      widget.data.zip = loaded.zip;
      if (!mounted) return;
      widget.onSignedIn(isNewUser: result.isNewUser);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      debugPrint('[SignIn] Apple sign-in failed: ${e.code} — ${e.message}');
      setState(() => _error = 'Apple sign-in failed. Please try again.');
    } catch (e, st) {
      // Logged, not swallowed — a bare "Sign-in failed" with nothing in
      // the console makes the actual cause (network, provider config,
      // native SDK error) unfindable later.
      debugPrint('[SignIn] Sign-in failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: 9),
              Text(
                'WAYPOINT',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Plan trips together',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to create or join a trip group with the people you travel with.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          if (Platform.isIOS)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _handle(AuthService.instance.signInWithApple),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                icon: const Icon(Icons.apple, size: 22),
                label: const Text('Continue with Apple'),
              ),
            ),
          if (Platform.isIOS) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _handle(AuthService.instance.signInWithGoogle),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
              label: const Text('Continue with Google'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmailSignInStep(data: widget.data, onSignedIn: widget.onSignedIn),
                        ),
                      ),
              child: const Text('Continue with email', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
