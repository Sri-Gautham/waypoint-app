import 'package:flutter/material.dart';

import '../../../models/group_draft.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/labeled_field.dart';
import '../../../widgets/step_header.dart';

class GroupDestinationStep extends StatefulWidget {
  const GroupDestinationStep({super.key, required this.draft, required this.onBack, required this.onContinue});

  final GroupDraft draft;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<GroupDestinationStep> createState() => _GroupDestinationStepState();
}

class _GroupDestinationStepState extends State<GroupDestinationStep> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          StepHeader(step: 2, total: 3, onBack: widget.onBack),
          const SizedBox(height: 24),
          const Text('Destination', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 1.5), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(child: _modeButton('General area', DestinationMode.area)),
                Expanded(child: _modeButton('Exact address', DestinationMode.exact)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (draft.destMode == DestinationMode.exact) ...[
                    LabeledField(label: 'Street address', hint: '1400 Elm Street', onChanged: (v) => draft.street = v),
                    const SizedBox(height: 16),
                    LabeledField(label: 'Apt / Unit (optional)', hint: 'Apt 4B', onChanged: (v) => draft.apt = v),
                    const SizedBox(height: 16),
                  ],
                  LabeledField(label: 'City', hint: 'South Lake Tahoe', onChanged: (v) => draft.city = v),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: LabeledField(label: 'State', hint: 'CA', onChanged: (v) => draft.state = v)),
                      const SizedBox(width: 16),
                      Expanded(child: LabeledField(label: 'ZIP code (optional)', hint: '96150', onChanged: (v) => draft.zip = v)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton(onPressed: widget.onContinue, child: const Text('Continue')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _modeButton(String label, DestinationMode mode) {
    final selected = widget.draft.destMode == mode;
    return GestureDetector(
      onTap: () => setState(() => widget.draft.destMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: selected ? AppColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }
}
