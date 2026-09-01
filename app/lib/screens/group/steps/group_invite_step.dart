import 'package:flutter/material.dart';

import '../../../models/group_draft.dart';
import '../../../models/trip.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/step_header.dart';

/// Final step of the create-group wizard: a quick review, then creates
/// the trip for real. The trip doesn't exist yet at this point (so
/// there's no real join code to show here) — sharing the code happens
/// from Trip Detail once creation succeeds, see TripDetailScreen.
class GroupInviteStep extends StatelessWidget {
  const GroupInviteStep({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onCreate,
    required this.creating,
    required this.error,
  });

  final GroupDraft draft;
  final VoidCallback onBack;
  final VoidCallback onCreate;
  final bool creating;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final destination = Trip.formatDestinationLine(city: draft.city, state: draft.state, zip: draft.zip);
    final dateLabel = Trip.formatDateLabel(draft.startDate, draft.endDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          StepHeader(step: 3, total: 3, onBack: onBack),
          const SizedBox(height: 24),
          Text('Review & create', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            "You'll get a code to share once the group is created.",
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: context.colors.border, width: 1.5), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.name.trim().isEmpty ? 'My Trip' : draft.name.trim(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  _reviewRow(context, Icons.location_on_outlined, destination),
                  _reviewRow(context, Icons.calendar_today_outlined, dateLabel),
                  if (draft.notes.trim().isNotEmpty) _reviewRow(context, Icons.notes_rounded, draft.notes.trim()),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(fontSize: 12.5, color: Colors.red)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: creating ? null : onCreate,
            child: creating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create group'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _reviewRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: context.colors.textTertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: context.colors.textPrimary))),
        ],
      ),
    );
  }
}
