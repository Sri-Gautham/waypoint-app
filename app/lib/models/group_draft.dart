enum DestinationMode { area, exact }

/// Form state collected across the "Create a group" wizard.
class GroupDraft {
  String name = '';
  String notes = '';
  DateTime? startDate;
  DateTime? endDate;
  int coverIndex = 0;

  DestinationMode destMode = DestinationMode.area;
  String street = '';
  String apt = '';
  String city = '';
  String state = '';
  String zip = '';

  final List<String> manualInvitees = [];
  final Set<String> selectedContactIds = {};
}
