import 'package:flutter/material.dart';

import '../../../models/onboarding_data.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/labeled_field.dart';

class CreateAccountStep extends StatelessWidget {
  const CreateAccountStep({super.key, required this.data, required this.onContinue});

  final OnboardingData data;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 20, color: AppColors.textPrimary),
                  const SizedBox(width: 9),
                  Text(
                    'WAYPOINT',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                  ),
                ],
              ),
              const Text(
                '1 / 4',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Text(
            'Create your account',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            "Takes about a minute. You'll verify your email and phone next.",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'First name',
                          hint: 'Jamie',
                          onChanged: (v) => data.firstName = v,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: LabeledField(
                          label: 'Last name',
                          hint: 'Rivera',
                          onChanged: (v) => data.lastName = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  LabeledField(
                    label: 'Email',
                    hint: 'jamie@email.com',
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => data.email = v,
                  ),
                  const SizedBox(height: 22),
                  LabeledField(
                    label: 'Phone number',
                    hint: '(555) 010-0198',
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => data.phone = v,
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton(onPressed: onContinue, child: const Text('Continue')),
          const SizedBox(height: 18),
          Center(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log in',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
