/// Form state collected across the sign-up flow.
class OnboardingData {
  String firstName = '';
  String lastName = '';
  String email = '';
  String phone = '';

  String street = '';
  String apt = '';
  String city = '';
  String state = '';
  String zip = '';

  bool faceIdEnabled = false;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final combined = (f + l).toUpperCase();
    return combined.isEmpty ? 'JR' : combined;
  }
}
