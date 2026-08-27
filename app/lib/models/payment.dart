/// A payment you recorded toward what you owe a specific person, reducing
/// their aggregated balance. Not attributed to any one trip.
class Payment {
  const Payment({required this.memberName, required this.amount});

  final String memberName;
  final double amount;
}
