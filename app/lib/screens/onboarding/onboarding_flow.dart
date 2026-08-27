import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../home/main_shell.dart';
import 'steps/all_set_step.dart';
import 'steps/create_account_step.dart';
import 'steps/home_address_step.dart';
import 'steps/verify_code_step.dart';

/// Owns the sign-up wizard's state and steps the user through it.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _data = OnboardingData();
  int _step = 0;

  void _goNext() => setState(() => _step = (_step + 1).clamp(0, 4));
  void _goBack() => setState(() => _step = (_step - 1).clamp(0, 4));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          0 => CreateAccountStep(data: _data, onContinue: _goNext),
          1 => VerifyCodeStep(
              stepNumber: 2,
              title: 'Verify your email',
              destinationLabel: _data.email.isEmpty ? 'your email' : _data.email,
              onBack: _goBack,
              onContinue: _goNext,
            ),
          2 => VerifyCodeStep(
              stepNumber: 3,
              title: 'Verify your phone',
              destinationLabel: _data.phone.isEmpty ? 'your phone' : _data.phone,
              onBack: _goBack,
              onContinue: _goNext,
            ),
          3 => HomeAddressStep(data: _data, onBack: _goBack, onContinue: _goNext),
          _ => AllSetStep(
              firstName: _data.firstName.isEmpty ? 'there' : _data.firstName,
              onGetStarted: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => MainShell(data: _data)),
                );
              },
            ),
        },
      ),
    );
  }
}
