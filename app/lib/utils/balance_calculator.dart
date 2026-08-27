import '../models/charge.dart';

/// Computes, for a set of charges, each other member's net balance with
/// "You": positive means they owe you, negative means you owe them.
/// Charges between two people who are neither you are ignored, since only
/// your own balances are tracked here.
Map<String, double> netBalancesByMember(Iterable<Charge> charges) {
  final net = <String, double>{};
  for (final charge in charges) {
    final share = charge.shareEach;
    for (final person in charge.splitWith) {
      if (person == charge.payer) continue;
      if (charge.payer == 'You') {
        net[person] = (net[person] ?? 0) + share;
      } else if (person == 'You') {
        net[charge.payer] = (net[charge.payer] ?? 0) - share;
      }
    }
  }
  return net;
}
