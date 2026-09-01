import 'dart:typed_data';

import '../theme/cover_theme.dart';
import 'activity_log_entry.dart';

enum MemberStatus { admin, member }

enum TripStatus { upcoming, past }

class TripMember {
  const TripMember({required this.userId, required this.name, required this.initials, required this.status});

  final String userId;
  final String name;
  final String initials;
  final MemberStatus status;
}

/// A real, backend-persisted trip group — see the `trips`/`trip_members`
/// Supabase tables and `TripsService`, which is the only place these get
/// constructed (via [fromRow]).
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.dateLabel,
    required this.startDate,
    required this.weatherTemp,
    required this.weatherCondition,
    required this.etaLabel,
    required this.cover,
    required this.members,
    required this.myRole,
    required this.joinCode,
    this.activityLog = const [],
    this.coverImageBytes,
  });

  final String id;
  final String name;
  final String destination;
  final String dateLabel;

  /// Used to compute [status]/[daysLeft] — null means "no date set yet".
  final DateTime? startDate;

  /// No real weather data source — always a placeholder. Not stored.
  final String weatherTemp;
  final String weatherCondition;

  /// Decorative only — the real per-user ETA-sharing feature (trip_day_status)
  /// is rendered separately in TripDetailScreen's ETA section, not from this.
  final String etaLabel;

  final CoverTheme cover;

  /// Everyone on the trip EXCEPT the signed-in user, who is rendered
  /// separately using [myRole] — matches the convention every screen
  /// that renders a roster already assumes (chat, balances, trip detail).
  final List<TripMember> members;

  /// The signed-in user's own role on this trip.
  final MemberStatus myRole;

  /// Real, redeemable via "Join with code" — see TripsService.redeemJoinCode.
  final String joinCode;

  /// Only ever populated for past trips; no real backend for this yet.
  final List<ActivityLogEntry> activityLog;

  /// Set only immediately after creation from the locally-generated cover
  /// (see CoverGenerationService) — NOT persisted, so this is null again
  /// after a reload; falls back to [cover]'s illustrated palette then.
  final Uint8List? coverImageBytes;

  TripStatus get status {
    if (startDate == null) return TripStatus.upcoming;
    final today = DateTime.now();
    final startDay = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return startDay.isBefore(todayDay) ? TripStatus.past : TripStatus.upcoming;
  }

  int get daysLeft {
    if (startDate == null) return 0;
    final diff = startDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String formatDateLabel(DateTime? start, DateTime? end) {
    if (start == null) return 'Date TBD';
    var label = '${_weekdays[start.weekday - 1]}, ${_months[start.month - 1]} ${start.day}';
    if (end != null) label += ' – ${_months[end.month - 1]} ${end.day}';
    return label;
  }

  static String formatDestinationLine({
    required String city,
    required String state,
    required String zip,
  }) {
    if (city.trim().isNotEmpty && state.trim().isNotEmpty) return '${city.trim()}, ${state.trim()}';
    if (zip.trim().isNotEmpty) return 'ZIP ${zip.trim()}';
    return 'Destination TBD';
  }

  /// Builds a [Trip] from a Supabase row shaped like TripsService's
  /// embedded select (`trips.*` plus a nested `trip_members` list, each
  /// with a nested `profiles` for the member's name). [currentUserId]
  /// splits the roster into [myRole] + everyone else in [members].
  factory Trip.fromRow(Map<String, dynamic> row, {required String currentUserId, Uint8List? generatedCoverBytes}) {
    final memberRows = (row['trip_members'] as List? ?? const []).cast<Map<String, dynamic>>();

    MemberStatus myRole = MemberStatus.member;
    final others = <TripMember>[];
    for (final m in memberRows) {
      final userId = m['user_id'] as String;
      final role = (m['role'] as String?) == 'admin' ? MemberStatus.admin : MemberStatus.member;
      if (userId == currentUserId) {
        myRole = role;
        continue;
      }
      final profile = m['profiles'] as Map<String, dynamic>?;
      final firstName = (profile?['first_name'] as String?) ?? '';
      final lastName = (profile?['last_name'] as String?) ?? '';
      final name = '$firstName $lastName'.trim();
      final letters = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');
      others.add(TripMember(
        userId: userId,
        name: name.isEmpty ? 'Member' : name,
        initials: letters.isEmpty ? '??' : letters.toUpperCase(),
        status: role,
      ));
    }

    final start = row['start_date'] == null ? null : DateTime.parse(row['start_date'] as String);
    final end = row['end_date'] == null ? null : DateTime.parse(row['end_date'] as String);
    final presetName = row['cover_preset'] as String?;

    return Trip(
      id: row['id'] as String,
      name: row['name'] as String,
      destination: formatDestinationLine(
        city: (row['destination_city'] as String?) ?? '',
        state: (row['destination_state'] as String?) ?? '',
        zip: (row['destination_zip'] as String?) ?? '',
      ),
      dateLabel: formatDateLabel(start, end),
      startDate: start,
      weatherTemp: '—°F',
      weatherCondition: 'Forecast pending',
      etaLabel: '—',
      cover: CoverTheme.all.firstWhere((t) => t.name == presetName, orElse: () => CoverTheme.all.first),
      members: others,
      myRole: myRole,
      joinCode: row['join_code'] as String,
      coverImageBytes: generatedCoverBytes,
    );
  }
}
