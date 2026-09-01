import 'package:flutter/widgets.dart';

import '../models/charge.dart';
import '../models/group_draft.dart';
import '../models/payment.dart';
import '../models/trip.dart';
import '../services/trips_service.dart';

/// App-wide mutable data: the trip list (real, backend-persisted — see
/// TripsService), their charges, and recorded payments. Charges/payments
/// are still local-only/in-memory (deliberately deferred, see PROGRESS.md
/// — they reference members by raw name string, not id, and migrating
/// that is a separate follow-up from real trip membership).
class AppData extends ChangeNotifier {
  AppData()
      : trips = [],
        chargesByTrip = {},
        payments = [];

  final List<Trip> trips;
  final Map<String, List<Charge>> chargesByTrip;
  final List<Payment> payments;

  bool loading = true;

  List<Trip> get upcoming => trips.where((t) => t.status == TripStatus.upcoming).toList();
  List<Trip> get past => trips.where((t) => t.status == TripStatus.past).toList();

  /// The trip Home's hero card and its own detail screen focus on: the
  /// most recently created/upcoming trip. Null once [loading] is false
  /// and the account genuinely has no trips yet.
  Trip? get nextTrip => upcoming.isNotEmpty ? upcoming.first : (trips.isNotEmpty ? trips.first : null);

  Future<void> loadTrips() async {
    loading = true;
    notifyListeners();
    final fetched = await TripsService.instance.fetchMyTrips();
    trips
      ..clear()
      ..addAll(fetched);
    for (final trip in trips) {
      chargesByTrip.putIfAbsent(trip.id, () => []);
    }
    loading = false;
    notifyListeners();
  }

  Future<Trip?> createTrip(GroupDraft draft) async {
    final trip = await TripsService.instance.createTrip(draft);
    if (trip != null) {
      trips.insert(0, trip);
      chargesByTrip[trip.id] = [];
      notifyListeners();
    }
    return trip;
  }

  Future<Trip?> joinTripWithCode(String code) async {
    final trip = await TripsService.instance.redeemJoinCode(code);
    if (trip != null) {
      trips.insert(0, trip);
      chargesByTrip[trip.id] = [];
      notifyListeners();
    }
    return trip;
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
