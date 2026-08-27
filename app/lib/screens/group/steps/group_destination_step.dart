import 'package:flutter/material.dart';

import '../../../models/group_draft.dart';
import '../../../services/cover_generation_service.dart';
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
  bool _generating = false;
  String? _error;

  String get _destinationQuery {
    final draft = widget.draft;
    final parts = [draft.city.trim(), draft.state.trim()].where((s) => s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(', ') : draft.name.trim();
  }

  Future<void> _generateCover() async {
    final query = _destinationQuery;
    if (query.isEmpty) {
      setState(() => _error = 'Add a city (or trip name) first.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    final result = await CoverGenerationService.instance.generate(query);
    if (!mounted) return;
    setState(() {
      _generating = false;
      if (result.succeeded) {
        widget.draft.generatedCoverBytes = result.imageBytes;
      } else {
        _error = switch (result.reason!) {
          CoverGenerationUnavailableReason.deviceNotCapable =>
            "This device can't generate covers — using the presets instead.",
          CoverGenerationUnavailableReason.noApiKey => 'Cover photos aren\'t set up on Android yet.',
          CoverGenerationUnavailableReason.cancelled => null,
          CoverGenerationUnavailableReason.unsupportedPlatform => "Cover generation isn't available on this platform.",
          CoverGenerationUnavailableReason.requestFailed => "Couldn't generate a cover — try again.",
        };
      }
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
                  LabeledField(label: 'City', hint: 'South Lake Tahoe', onChanged: (v) => setState(() => draft.city = v)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: LabeledField(label: 'State', hint: 'CA', onChanged: (v) => setState(() => draft.state = v))),
                      const SizedBox(width: 16),
                      Expanded(child: LabeledField(label: 'ZIP code (optional)', hint: '96150', onChanged: (v) => draft.zip = v)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (draft.generatedCoverBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(draft.generatedCoverBytes!, width: 44, height: 44, fit: BoxFit.cover),
                          )
                        else
                          const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.generatedCoverBytes != null ? 'Generated cover ready' : 'Generate a cover',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Based on this destination, on-device.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _generating ? null : _generateCover,
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            foregroundColor: AppColors.accent,
                            side: BorderSide.none,
                            backgroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          child: _generating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(draft.generatedCoverBytes != null ? 'Regenerate' : 'Generate'),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ],
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
