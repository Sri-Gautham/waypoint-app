import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small-caps label above an underline text field, matching the design.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.onChanged,
    this.hint,
    this.keyboardType,
    this.initialValue,
    this.controller,
  }) : assert(
          controller == null || initialValue == null,
          'Pass either a controller or an initialValue, not both.',
        );

  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final String? initialValue;

  /// When the field's value needs to be updated programmatically (e.g. an
  /// "use current location" action), pass a controller instead of
  /// [initialValue] so the displayed text stays in sync without relying on
  /// widget keys.
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(fontSize: 15, color: context.colors.textPrimary),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
