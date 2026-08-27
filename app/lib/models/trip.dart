import '../theme/cover_theme.dart';

class TripMember {
  const TripMember({required this.initials});
  final String initials;
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
      TripMember(initials: 'SP'),
      TripMember(initials: 'AK'),
    ],
  );
}
