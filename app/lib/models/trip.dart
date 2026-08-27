import '../theme/cover_theme.dart';

enum MemberStatus { admin, member, invited }

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
    required this.name,
    required this.destination,
    required this.dateLabel,
    required this.daysLeft,
    required this.weatherTemp,
    required this.weatherCondition,
    required this.etaLabel,
    required this.cover,
    required this.members,
  });

  final String name;
  final String destination;
  final String dateLabel;
  final int daysLeft;
  final String weatherTemp;
  final String weatherCondition;
  final String etaLabel;
  final CoverTheme cover;

  /// Everyone but the signed-in user, who is always the admin and is
  /// prepended separately wherever the full roster is shown.
  final List<TripMember> members;

  static const sampleNextTrip = Trip(
    name: 'Lake Tahoe Crew',
    destination: 'Lake Tahoe, CA',
    dateLabel: 'This Sat, Sep 6',
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
}
