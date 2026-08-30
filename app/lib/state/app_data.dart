import 'package:flutter/widgets.dart';

import '../data/sample_charges.dart';
import '../models/charge.dart';
import '../models/payment.dart';
import '../models/trip.dart';

/// App-wide mutable data: the trip list, their charges, and recorded
/// payments. Everything here is sample/in-memory only (no backend yet).
class AppData extends ChangeNotifier {
  AppData()
      : trips = List<Trip>.of(Trip.all),
        chargesByTrip = seedCharges(),
        payments = [];

  final List<Trip> trips;
  final Map<String, List<Charge>> chargesByTrip;
  final List<Payment> payments;

  List<Trip> get upcoming => trips.where((t) => t.status == TripStatus.upcoming).toList();
  List<Trip> get past => trips.where((t) => t.status == TripStatus.past).toList();

  /// The trip Home's hero card and its own detail screen focus on: the
  /// most recently created/upcoming trip.
  Trip get nextTrip => upcoming.isNotEmpty ? upcoming.first : trips.first;

  void addTrip(Trip trip) {
    trips.insert(0, trip);
    chargesByTrip[trip.id] = [];
    notifyListeners();
  }

  void addCharge(String tripId, Charge charge) {
    (chargesByTrip[tripId] ??= []).add(charge);
    notifyListeners();
  }

  void removeCharge(String tripId, String chargeId) {
    chargesByTrip[tripId]?.removeWhere((c) => c.id == chargeId);
    notifyListeners();
  }

  void addPayment(Payment payment) {
    payments.add(payment);
    notifyListeners();
  }
}

/// Makes the single [AppData] instance available anywhere below it via
/// [AppDataScope.of], and rebuilds dependents automatically whenever it
/// calls `notifyListeners()`.
class AppDataScope extends InheritedNotifier<AppData> {
  const AppDataScope({super.key, required AppData super.notifier, required super.child});

  static AppData of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppDataScope>();
    assert(scope != null, 'No AppDataScope found in context');
    return scope!.notifier!;
  }
}
