import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group_draft.dart';
import '../models/trip.dart';

enum JoinCodeFailureReason { invalidCode, throttled, notSignedIn, requestFailed }

class JoinCodeResult {
  // `trip` here is deliberately typed non-nullable (a success always has
  // one) even though the field it's assigned into is nullable (also
  // holds null on failure) — `this.trip` would make the parameter
  // nullable too, matching the field instead of the constructor's
  // actual contract, so not using an initializing formal here.
  // ignore: prefer_initializing_formals
  const JoinCodeResult.success(Trip trip) : trip = trip, reason = null;
  const JoinCodeResult.failure(this.reason) : trip = null;

  final Trip? trip;
  final JoinCodeFailureReason? reason;
  bool get succeeded => trip != null;
}

/// Real, backend-persisted trips — see the `trips`/`trip_members` tables
/// and the `create_trip`/`redeem_trip_join_code`/`leave_trip` RPCs, which
/// are the only way `trip_members` is ever written (see PROGRESS.md for
/// the full RLS design: trip_members has no direct insert/update/delete
/// policy for regular clients at all).
class TripsService {
  TripsService._();
  static final instance = TripsService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const _embed = '*, trip_members(user_id, role, profiles(first_name, last_name))';

  Future<List<Trip>> fetchMyTrips() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client.from('trips').select(_embed).order('created_at');
      return (rows as List)
          .map((r) => Trip.fromRow(r as Map<String, dynamic>, currentUserId: user.id))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Trip?> createTrip(GroupDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final created = await _client.rpc('create_trip', params: {
        'p_name': draft.name.trim().isEmpty ? 'My Trip' : draft.name.trim(),
        'p_notes': draft.notes.trim().isEmpty ? null : draft.notes.trim(),
        'p_start_date': draft.startDate?.toIso8601String().split('T').first,
        'p_end_date': draft.endDate?.toIso8601String().split('T').first,
        'p_destination_mode': draft.destMode == DestinationMode.exact ? 'exact' : 'area',
        'p_destination_street': draft.destMode == DestinationMode.exact && draft.street.trim().isNotEmpty ? draft.street.trim() : null,
        'p_destination_unit': draft.destMode == DestinationMode.exact && draft.apt.trim().isNotEmpty ? draft.apt.trim() : null,
        'p_destination_city': draft.city.trim().isEmpty ? null : draft.city.trim(),
        'p_destination_state': draft.state.trim().isEmpty ? null : draft.state.trim(),
        'p_destination_zip': draft.zip.trim().isEmpty ? null : draft.zip.trim(),
        'p_cover_preset': draft.generatedCoverBytes == null ? _coverPresetName(draft.coverIndex) : null,
      }) as Map<String, dynamic>;

      // create_trip returns just the trips row (no embedded trip_members
      // yet at that point) — re-fetch by id to get it in the same shape
      // fetchMyTrips returns, rather than hand-building a Trip here.
      final full = await _client.from('trips').select(_embed).eq('id', created['id'] as String).single();
      return Trip.fromRow(full, currentUserId: user.id, generatedCoverBytes: draft.generatedCoverBytes);
    } catch (_) {
      return null;
    }
  }

  String _coverPresetName(int index) {
    const names = ['Mountain Lake', 'Beach', 'Desert', 'Forest'];
    return names[index.clamp(0, names.length - 1)];
  }

  /// Distinguishes why a join failed (see [JoinCodeFailureReason]) by
  /// matching the RPC's raised error text — redeem_trip_join_code raises
  /// 'Invalid code' or 'Too many attempts...' verbatim, see the
  /// create_trip_membership_schema migration.
  Future<JoinCodeResult> redeemJoinCode(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) return const JoinCodeResult.failure(JoinCodeFailureReason.notSignedIn);
    try {
      final tripId = await _client.rpc('redeem_trip_join_code', params: {'p_code': code.trim()}) as String;
      final full = await _client.from('trips').select(_embed).eq('id', tripId).single();
      return JoinCodeResult.success(Trip.fromRow(full, currentUserId: user.id));
    } on PostgrestException catch (e) {
      if (e.message.contains('Too many attempts')) {
        return const JoinCodeResult.failure(JoinCodeFailureReason.throttled);
      }
      if (e.message.contains('Invalid code')) {
        return const JoinCodeResult.failure(JoinCodeFailureReason.invalidCode);
      }
      return const JoinCodeResult.failure(JoinCodeFailureReason.requestFailed);
    } catch (_) {
      return const JoinCodeResult.failure(JoinCodeFailureReason.requestFailed);
    }
  }

  Future<bool> leaveTrip(String tripId) async {
    try {
      await _client.rpc('leave_trip', params: {'p_trip_id': tripId});
      return true;
    } catch (_) {
      return false;
    }
  }
}
