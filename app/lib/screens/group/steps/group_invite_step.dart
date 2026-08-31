import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/sample_contacts.dart';
import '../../../models/group_draft.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/step_header.dart';

class GroupInviteStep extends StatefulWidget {
  const GroupInviteStep({super.key, required this.draft, required this.onBack, required this.onCreate});

  final GroupDraft draft;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  State<GroupInviteStep> createState() => _GroupInviteStepState();
}

class _GroupInviteStepState extends State<GroupInviteStep> {
  final _inviteController = TextEditingController();
  bool _copied = false;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  String get _inviteCode {
    final raw = widget.draft.name.trim().isEmpty ? 'TRIP' : widget.draft.name;
    final letters = raw.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
    final code = letters.isEmpty ? 'TRIP' : letters.substring(0, letters.length > 6 ? 6 : letters.length);
    return '$code-482';
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _inviteCode));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _addInvitee() {
    final text = _inviteController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.draft.manualInvitees.add(text);
      _inviteController.clear();
    });
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
          StepHeader(step: 3, total: 3, onBack: widget.onBack),
          const SizedBox(height: 24),
          Text('Invite members', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: context.colors.border, width: 1.5), borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('INVITE CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textSecondary, letterSpacing: 0.4)),
                              const SizedBox(height: 2),
                              Text(_inviteCode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _copyCode,
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            foregroundColor: context.colors.accent,
                            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          child: Text(_copied ? 'Copied!' : 'Copy'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('ADD BY PHONE OR EMAIL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary, letterSpacing: 0.4)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inviteController,
                          decoration: const InputDecoration(hintText: 'Phone or email', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addInvitee,
                        style: ElevatedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  if (draft.manualInvitees.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final invitee in List<String>.from(draft.manualInvitees))
                          Chip(
                            label: Text(invitee, style: const TextStyle(fontSize: 12.5)),
                            backgroundColor: context.colors.accentTint,
                            side: BorderSide.none,
                            onDeleted: () => setState(() => draft.manualInvitees.remove(invitee)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text('FROM YOUR CONTACTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary, letterSpacing: 0.4)),
                  for (final contact in sampleContacts)
                    CheckboxListTile(
                      value: draft.selectedContactIds.contains(contact.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked ?? false) {
                            draft.selectedContactIds.add(contact.id);
                          } else {
                            draft.selectedContactIds.remove(contact.id);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: context.colors.accent,
                      title: Text(contact.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                      subtitle: Text(contact.sub, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                    ),
                ],
              ),
            ),
          ),
          ElevatedButton(onPressed: widget.onCreate, child: const Text('Create group')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
