import 'package:flutter/material.dart';

import '../../data/sample_contacts.dart';
import '../../models/group_draft.dart';
import '../../models/trip.dart';
import '../../state/app_data.dart';
import '../../theme/cover_theme.dart';
import '../trip/trip_detail_screen.dart';
import 'steps/group_basics_step.dart';
import 'steps/group_destination_step.dart';
import 'steps/group_invite_step.dart';

/// 3-step wizard: cover/name/dates, destination, invite — then creates a
/// new [Trip] in [AppData] and opens its detail screen.
class CreateGroupFlow extends StatefulWidget {
  const CreateGroupFlow({super.key});

  @override
  State<CreateGroupFlow> createState() => _CreateGroupFlowState();
}

class _CreateGroupFlowState extends State<CreateGroupFlow> {
  final _draft = GroupDraft();
  int _step = 0;

  void _goNext() => setState(() => _step = (_step + 1).clamp(0, 2));
  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step = (_step - 1).clamp(0, 2));
  }

  String _formatDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  void _createGroup() {
    final destinationLine = _draft.city.trim().isNotEmpty && _draft.state.trim().isNotEmpty
        ? '${_draft.city.trim()}, ${_draft.state.trim()}'
        : (_draft.zip.trim().isNotEmpty ? 'ZIP ${_draft.zip.trim()}' : 'Destination TBD');

    String dateLabel = 'Date TBD';
    int daysLeft = 0;
    final start = _draft.startDate;
    if (start != null) {
      dateLabel = _formatDate(start);
      final end = _draft.endDate;
      if (end != null) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        dateLabel += ' – ${months[end.month - 1]} ${end.day}';
      }
      daysLeft = start.difference(DateTime.now()).inDays;
      if (daysLeft < 0) daysLeft = 0;
    }

    final contactMembers = sampleContacts
        .where((c) => _draft.selectedContactIds.contains(c.id))
        .map((c) => TripMember(name: c.name, initials: c.initials, status: MemberStatus.invited, distance: 'TBD'));
    final manualMembers = _draft.manualInvitees.map((label) {
      final letters = label.replaceAll(RegExp('[^a-zA-Z]'), '');
      final initials = (letters.length >= 2 ? letters.substring(0, 2) : letters).toUpperCase();
      return TripMember(name: label, initials: initials.isEmpty ? '??' : initials, status: MemberStatus.invited, distance: 'TBD');
    });

    final trip = Trip(
      id: 'g-${DateTime.now().millisecondsSinceEpoch}',
      name: _draft.name.trim().isEmpty ? 'My Trip' : _draft.name.trim(),
      destination: destinationLine,
      dateLabel: dateLabel,
      status: TripStatus.upcoming,
      daysLeft: daysLeft,
      weatherTemp: '75°F',
      weatherCondition: 'Forecast pending',
      etaLabel: 'TBD',
      cover: CoverTheme.all[_draft.coverIndex],
      members: [...contactMembers, ...manualMembers],
      coverImageBytes: _draft.generatedCoverBytes,
    );

    AppDataScope.of(context).addTrip(trip);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          0 => GroupBasicsStep(draft: _draft, onClose: _goBack, onContinue: _goNext),
          1 => GroupDestinationStep(draft: _draft, onBack: _goBack, onContinue: _goNext),
          _ => GroupInviteStep(draft: _draft, onBack: _goBack, onCreate: _createGroup),
        },
      ),
    );
  }
}
