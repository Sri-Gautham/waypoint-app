import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../home/main_shell.dart';
import 'steps/all_set_step.dart';
import 'steps/enable_face_id_step.dart';
import 'steps/profile_details_step.dart';
import 'steps/sign_in_step.dart';

enum _Step { signIn, profileDetails, allSet, enableFaceId }

/// Owns the sign-up wizard's state and steps the user through it:
/// Apple/Google sign-in -> profile details -> all set -> (optional)
/// enable Face ID -> Home.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _data = OnboardingData();
  _Step _step = _Step.signIn;
  bool _isNewUser = false;

  void _enterApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainShell(data: _data)),
    );
  }

  void _onAllSet() {
    if (_isNewUser) {
      setState(() => _step = _Step.enableFaceId);
    } else {
      _enterApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          _Step.signIn => SignInStep(
              data: _data,
              onSignedIn: ({required isNewUser}) => setState(() {
                _isNewUser = isNewUser;
                _step = _Step.profileDetails;
              }),
            ),
          _Step.profileDetails => ProfileDetailsStep(
              data: _data,
              onBack: () => setState(() => _step = _Step.signIn),
              onContinue: () => setState(() => _step = _Step.allSet),
            ),
          _Step.allSet => AllSetStep(
              firstName: _data.firstName.isEmpty ? 'there' : _data.firstName,
              onGetStarted: _onAllSet,
            ),
          _Step.enableFaceId => EnableFaceIdStep(onDone: _enterApp),
        },
      ),
    );
  }
}
