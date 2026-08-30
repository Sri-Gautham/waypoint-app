import 'package:flutter/material.dart';

import '../../../models/onboarding_data.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/labeled_field.dart';
import '../../../widgets/step_header.dart';

/// Collects what Apple/Google sign-in can't give us: phone number and
/// home address (used to plan routes/carpools). Name and email already
/// came from the OAuth provider by the time this step is reached — except
/// for email sign-in, which gives no name at all, so this step also
/// collects first/last name in that one case (see [_needsName]).
class ProfileDetailsStep extends StatefulWidget {
  const ProfileDetailsStep({super.key, required this.data, required this.onBack, required this.onContinue});

  final OnboardingData data;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<ProfileDetailsStep> createState() => _ProfileDetailsStepState();
}

class _ProfileDetailsStepState extends State<ProfileDetailsStep> {
  bool get _needsName => widget.data.firstName.isEmpty && widget.data.lastName.isEmpty;

  late final _firstNameController = TextEditingController();
  late final _lastNameController = TextEditingController();
  late final _phoneController = TextEditingController(text: widget.data.phone);
  late final _streetController = TextEditingController(text: widget.data.street);
  late final _aptController = TextEditingController(text: widget.data.apt);
  late final _cityController = TextEditingController(text: widget.data.city);
  late final _stateController = TextEditingController(text: widget.data.state);
  late final _zipController = TextEditingController(text: widget.data.zip);

  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
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
    setState(() {});
  }

  Future<void> _continue() async {
    if (_needsName && widget.data.firstName.trim().isEmpty) {
      setState(() => _nameError = 'Enter your first name.');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    try {
      await AuthService.instance.saveProfile(widget.data);
    } catch (_) {
      // Best-effort: the data still lives in `widget.data` for this
      // session even if the write fails, so don't block the flow on it.
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onContinue();
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
          StepHeader(step: 1, total: 1, onBack: widget.onBack),
          const SizedBox(height: 28),
          Text(
            'A few more details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Used to plan routes and carpools for your trips. You can update this anytime.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_needsName) ...[
                    Row(
                      children: [
                        Expanded(
                          child: LabeledField(
                            label: 'First name',
                            hint: 'Jamie',
                            controller: _firstNameController,
                            onChanged: (v) {
                              data.firstName = v;
                              if (_nameError != null) setState(() => _nameError = null);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: LabeledField(
                            label: 'Last name',
                            hint: 'Rivera',
                            controller: _lastNameController,
                            onChanged: (v) => data.lastName = v,
                          ),
                        ),
                      ],
                    ),
                    if (_nameError != null) ...[
                      const SizedBox(height: 6),
                      Text(_nameError!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 22),
                  ],
                  LabeledField(
                    label: 'Phone number',
                    hint: '(555) 010-0198',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => data.phone = v,
                  ),
                  const SizedBox(height: 22),
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
          ElevatedButton(
            onPressed: _saving ? null : _continue,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Finish'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
