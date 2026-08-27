import '../theme/cover_theme.dart';
import 'activity_log_entry.dart';

enum MemberStatus { admin, member, invited }

enum TripStatus { upcoming, past }

class TripMember {
  const TripMember({
    required this.name,
    required this.initials,
    required this.status,
    required this.distance,
  });

  final String name;
  final String initials;
  final MemberStatus status;

  /// Approximate distance from this member's home to the trip destination.
  /// "TBD" until a member accepts and their home address is on file.
  final String distance;
}

/// A trip group. Sample/placeholder data for now — will come from the
/// backend once groups and membership are wired up.
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.dateLabel,
    required this.status,
    required this.daysLeft,
    required this.weatherTemp,
    required this.weatherCondition,
    required this.etaLabel,
    required this.cover,
    required this.members,
    this.activityLog = const [],
  });

  final String id;
  final String name;
  final String destination;
  final String dateLabel;
  final TripStatus status;
  final int daysLeft;
  final String weatherTemp;
  final String weatherCondition;
  final String etaLabel;
  final CoverTheme cover;

  /// Everyone but the signed-in user, who is always the admin and is
  /// prepended separately wherever the full roster is shown.
  final List<TripMember> members;

  /// Only populated for past trips.
  final List<ActivityLogEntry> activityLog;

  static const lakeTahoe = Trip(
    id: 't1',
    name: 'Lake Tahoe Crew',
    destination: 'Lake Tahoe, CA',
    dateLabel: 'This Sat, Sep 6',
    status: TripStatus.upcoming,
    daysLeft: 12,
    weatherTemp: '72°F',
    weatherCondition: 'Sunny, trip day',
    etaLabel: '2:30 PM',
    cover: CoverTheme.mountainLake,
    members: [
      TripMember(name: 'Sam Park', initials: 'SP', status: MemberStatus.member, distance: '38 mi'),
      TripMember(name: 'Alex Kim', initials: 'AK', status: MemberStatus.member, distance: '210 mi'),
      TripMember(name: 'Priya Nair', initials: 'PN', status: MemberStatus.invited, distance: '95 mi'),
      TripMember(name: 'Jordan Lee', initials: 'JL', status: MemberStatus.invited, distance: '340 mi'),
    ],
  );

  static const weekendCabin = Trip(
    id: 't2',
    name: 'Weekend at the Cabin',
    destination: 'Big Bear, CA',
    dateLabel: 'Oct 18 – Oct 20',
    status: TripStatus.upcoming,
    daysLeft: 47,
    weatherTemp: '58°F',
    weatherCondition: 'Partly cloudy',
    etaLabel: '4:15 PM',
    cover: CoverTheme.forest,
    members: [
      TripMember(name: 'Priya Nair', initials: 'PN', status: MemberStatus.member, distance: '95 mi'),
      TripMember(name: 'Jordan Lee', initials: 'JL', status: MemberStatus.member, distance: '340 mi'),
      TripMember(name: 'Sam Park', initials: 'SP', status: MemberStatus.member, distance: '38 mi'),
    ],
  );

  static const napaWineTour = Trip(
    id: 't3',
    name: 'Napa Wine Tour',
    destination: 'Napa, CA',
    dateLabel: 'Jun 12 – Jun 13',
    status: TripStatus.past,
    daysLeft: 0,
    weatherTemp: '81°F',
    weatherCondition: 'Sunny',
    etaLabel: '—',
    cover: CoverTheme.beach,
    members: [
      TripMember(name: 'Sam Park', initials: 'SP', status: MemberStatus.member, distance: '38 mi'),
      TripMember(name: 'Alex Kim', initials: 'AK', status: MemberStatus.member, distance: '210 mi'),
      TripMember(name: 'Morgan Diaz', initials: 'MD', status: MemberStatus.member, distance: '150 mi'),
    ],
    activityLog: [
      ActivityLogEntry(kind: ActivityLogKind.person, text: 'Morgan Diaz joined the trip', time: 'Jun 10'),
      ActivityLogEntry(kind: ActivityLogKind.receipt, text: 'You added an expense: Winery tour tickets (\$150)', time: 'Jun 12'),
      ActivityLogEntry(kind: ActivityLogKind.photo, text: 'Sam Park uploaded 3 photos', time: 'Jun 12'),
      ActivityLogEntry(kind: ActivityLogKind.chat, text: 'Alex Kim: "That was an amazing trip."', time: 'Jun 13'),
      ActivityLogEntry(kind: ActivityLogKind.receipt, text: 'Morgan Diaz added an expense: Lunch (\$60)', time: 'Jun 13'),
    ],
  );

  static const sampleNextTrip = lakeTahoe;

  static const all = [lakeTahoe, weekendCabin, napaWineTour];

  static List<Trip> get upcoming => all.where((t) => t.status == TripStatus.upcoming).toList();
  static List<Trip> get past => all.where((t) => t.status == TripStatus.past).toList();
}
