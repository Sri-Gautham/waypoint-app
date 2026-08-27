import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/otp_code_row.dart';
import '../../../widgets/step_header.dart';

/// Shared 6-digit verification step, used for both email and phone.
class VerifyCodeStep extends StatefulWidget {
  const VerifyCodeStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.destinationLabel,
    required this.onBack,
    required this.onContinue,
  });

  final int stepNumber;
  final String title;
  final String destinationLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<VerifyCodeStep> createState() => _VerifyCodeStepState();
}

class _VerifyCodeStepState extends State<VerifyCodeStep> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          StepHeader(step: widget.stepNumber, onBack: widget.onBack),
          const SizedBox(height: 36),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the 6-digit code we sent to',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          Text(
            widget.destinationLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 32),
          OtpCodeRow(onChanged: (code) => setState(() => _code = code)),
          const SizedBox(height: 20),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              children: [
                TextSpan(text: "Didn't get a code? "),
                TextSpan(text: 'Resend', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _code.length == 6 ? widget.onContinue : null,
            child: const Text('Continue'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
