import 'package:flutter/material.dart';

import '../../../models/onboarding_data.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/labeled_field.dart';
import '../../../widgets/step_header.dart';

class HomeAddressStep extends StatefulWidget {
  const HomeAddressStep({
    super.key,
    required this.data,
    required this.onBack,
    required this.onContinue,
  });

  final OnboardingData data;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<HomeAddressStep> createState() => _HomeAddressStepState();
}

class _HomeAddressStepState extends State<HomeAddressStep> {
  late final _streetController = TextEditingController(text: widget.data.street);
  late final _aptController = TextEditingController(text: widget.data.apt);
  late final _cityController = TextEditingController(text: widget.data.city);
  late final _stateController = TextEditingController(text: widget.data.state);
  late final _zipController = TextEditingController(text: widget.data.zip);

  @override
  void dispose() {
    _streetController.dispose();
    _aptController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _useCurrentLocation() {
    final data = widget.data;
    data
      ..street = '1400 Elm Street'
      ..apt = ''
      ..city = 'Austin'
      ..state = 'TX'
      ..zip = '78701';
    _streetController.text = data.street;
    _aptController.text = data.apt;
    _cityController.text = data.city;
    _stateController.text = data.state;
    _zipController.text = data.zip;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          StepHeader(step: 4, onBack: widget.onBack),
          const SizedBox(height: 28),
          Text(
            'Add your home address',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Used to plan routes and carpools for your trips. You can update it anytime.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 15, color: AppColors.accent),
                    label: const Text('Use current location'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.accentTint,
                      foregroundColor: AppColors.accent,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      side: BorderSide.none,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LabeledField(
                    label: 'Street address',
                    hint: '1400 Elm Street',
                    controller: _streetController,
                    onChanged: (v) => data.street = v,
                  ),
                  const SizedBox(height: 18),
                  LabeledField(
                    label: 'Apt / Unit (optional)',
                    hint: 'Apt 4B',
                    controller: _aptController,
                    onChanged: (v) => data.apt = v,
                  ),
                  const SizedBox(height: 18),
                  LabeledField(
                    label: 'City',
                    hint: 'Austin',
                    controller: _cityController,
                    onChanged: (v) => data.city = v,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'State',
                          hint: 'TX',
                          controller: _stateController,
                          onChanged: (v) => data.state = v,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: LabeledField(
                          label: 'ZIP code',
                          hint: '78701',
                          controller: _zipController,
                          onChanged: (v) => data.zip = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: widget.onContinue, child: const Text('Finish')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
