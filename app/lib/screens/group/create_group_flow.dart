import 'package:flutter/material.dart';

import '../../models/group_draft.dart';
import '../../state/app_data.dart';
import '../trip/trip_detail_screen.dart';
import 'steps/group_basics_step.dart';
import 'steps/group_destination_step.dart';
import 'steps/group_invite_step.dart';

/// 3-step wizard: cover/name/dates, destination, review&create — then
/// creates a real, backend-persisted trip (see TripsService) and opens
/// its detail screen.
class CreateGroupFlow extends StatefulWidget {
  const CreateGroupFlow({super.key});

  @override
  State<CreateGroupFlow> createState() => _CreateGroupFlowState();
}

class _CreateGroupFlowState extends State<CreateGroupFlow> {
  final _draft = GroupDraft();
  int _step = 0;
  bool _creating = false;
  String? _error;

  void _goNext() => setState(() => _step = (_step + 1).clamp(0, 2));
  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step = (_step - 1).clamp(0, 2));
  }

  Future<void> _createGroup() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    final trip = await AppDataScope.of(context).createTrip(_draft);
    if (!mounted) return;
    if (trip == null) {
      setState(() {
        _creating = false;
        _error = "Couldn't create the group — try again.";
      });
      return;
    }
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
          _ => GroupInviteStep(draft: _draft, onBack: _goBack, onCreate: _createGroup, creating: _creating, error: _error),
        },
      ),
    );
  }
}
