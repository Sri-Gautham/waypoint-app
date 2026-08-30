import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nearby_place.dart';
import '../models/saved_place.dart';

/// Shared, group-wide "things to do" list per trip — see the trip_places
/// table (RLS: any signed-in user can read/add/remove any trip's rows,
/// same interim looseness as trip_day_status, since trips have no real
/// backend membership concept yet to check against).
class TripPlacesService {
  TripPlacesService._();
  static final instance = TripPlacesService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<SavedPlace>> fetchSavedPlaces(String tripId) async {
    try {
      final rows = await _client.from('trip_places').select().eq('trip_id', tripId).order('created_at');
      return (rows as List).map((r) => SavedPlace.fromRow(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns true on success. A duplicate add (same place already saved
  /// to this trip) is treated as a harmless no-op success, not an error —
  /// the unique(trip_id, fsq_id) constraint on the table is what enforces
  /// that, via ignoreDuplicates below.
  ///
  /// Deliberately NOT a merge-on-conflict upsert: only SELECT/INSERT/
  /// DELETE policies exist on this table (no UPDATE policy — re-adding
  /// a place shouldn't reassign added_by/added_by_name to whoever
  /// re-added it), and a merge-style upsert's conflict path needs
  /// UPDATE privileges to even attempt the no-op, which RLS would then
  /// reject outright. ignoreDuplicates keeps this on the INSERT path
  /// (ON CONFLICT DO NOTHING), which only needs the INSERT policy.
  Future<bool> addPlace({required String tripId, required NearbyPlace place, required String addedByName}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('trip_places').upsert(
        {
          'trip_id': tripId,
          'fsq_id': place.fsqId,
          'name': place.name,
          'category': place.category,
          'address': place.address,
          'lat': place.lat,
          'lng': place.lng,
          'added_by': user.id,
          'added_by_name': addedByName,
        },
        onConflict: 'trip_id,fsq_id',
        ignoreDuplicates: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removePlace(String rowId) async {
    try {
      await _client.from('trip_places').delete().eq('id', rowId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
