import 'dart:typed_data';

enum DestinationMode { area, exact }

/// Form state collected across the "Create a group" wizard.
class GroupDraft {
  String name = '';
  String notes = '';
  DateTime? startDate;
  DateTime? endDate;
  int coverIndex = 0;

  /// Set once cover generation succeeds (see CoverGenerationService,
  /// triggered from GroupDestinationStep). Takes priority over
  /// [coverIndex]'s preset when building the Trip — cleared if the user
  /// picks a preset swatch instead.
  Uint8List? generatedCoverBytes;

  DestinationMode destMode = DestinationMode.area;
  String street = '';
  String apt = '';
  String city = '';
  String state = '';
  String zip = '';

  final List<String> manualInvitees = [];
  final Set<String> selectedContactIds = {};
}
