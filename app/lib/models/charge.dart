enum ChargeCategory { food, transport, lodging, activity }

/// A single expense logged against a trip and split among some subset of
/// its members (which always includes the payer).
class Charge {
  const Charge({
    required this.id,
    required this.tripId,
    required this.payer,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    required this.splitWith,
  });

  final String id;
  final String tripId;

  /// 'You' or a trip member's name.
  final String payer;
  final double amount;
  final String description;
  final ChargeCategory category;
  final String date;

  /// Names of everyone this charge is split among, including the payer.
  final List<String> splitWith;

  double get shareEach => amount / splitWith.length;
}
