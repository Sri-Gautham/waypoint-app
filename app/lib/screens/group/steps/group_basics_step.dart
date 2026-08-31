import 'package:flutter/material.dart';

import '../../../models/group_draft.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/cover_theme.dart';
import '../../../widgets/labeled_field.dart';
import '../../../widgets/step_header.dart';

class GroupBasicsStep extends StatefulWidget {
  const GroupBasicsStep({super.key, required this.draft, required this.onClose, required this.onContinue});

  final GroupDraft draft;
  final VoidCallback onClose;
  final VoidCallback onContinue;

  @override
  State<GroupBasicsStep> createState() => _GroupBasicsStepState();
}

class _GroupBasicsStepState extends State<GroupBasicsStep> {
  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? widget.draft.startDate : widget.draft.endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        widget.draft.startDate = picked;
      } else {
        widget.draft.endDate = picked;
      }
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          StepHeader(step: 1, total: 3, onBack: widget.onClose),
          const SizedBox(height: 24),
          Text('New trip', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COVER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary, letterSpacing: 0.4)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (i, theme) in CoverTheme.all.indexed)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _CoverSwatch(
                            theme: theme,
                            selected: draft.generatedCoverBytes == null && draft.coverIndex == i,
                            onTap: () => setState(() {
                              draft.coverIndex = i;
                              draft.generatedCoverBytes = null;
                            }),
                          ),
                        ),
                    ],
                  ),
                  if (draft.generatedCoverBytes != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(draft.generatedCoverBytes!, width: 40, height: 40, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Using your generated cover — set on the Destination step.',
                            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  LabeledField(label: 'Trip name', hint: 'Lake Tahoe Crew', onChanged: (v) => draft.name = v),
                  const SizedBox(height: 18),
                  LabeledField(label: 'Notes (optional)', hint: 'Cabin weekend, bring hiking boots', onChanged: (v) => draft.notes = v),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(label: 'Start date', valueLabel: _formatDate(draft.startDate), onTap: () => _pickDate(isStart: true)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DateField(label: 'End date (optional)', valueLabel: _formatDate(draft.endDate), onTap: () => _pickDate(isStart: false)),
                      ),
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
}

class _CoverSwatch extends StatelessWidget {
  const _CoverSwatch({required this.theme, required this.selected, required this.onTap});

  final CoverTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? theme.accent : Colors.transparent, width: 2.5),
        ),
        child: Icon(_iconFor(theme.name), size: 22, color: theme.accent),
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'Beach':
        return Icons.waves_rounded;
      case 'Desert':
        return Icons.wb_sunny_outlined;
      case 'Forest':
        return Icons.park_outlined;
      default:
        return Icons.landscape_outlined;
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.valueLabel, required this.onTap});

  final String label;
  final String valueLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary, letterSpacing: 0.4)),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.border, width: 1.5))),
            child: Text(valueLabel, style: TextStyle(fontSize: 15, color: context.colors.textPrimary)),
          ),
        ),
      ],
    );
  }
}
