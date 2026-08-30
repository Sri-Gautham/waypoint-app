/// A venue from a Foursquare nearby search — browse-only until someone
/// adds it to the trip (see [SavedPlace]).
class NearbyPlace {
  const NearbyPlace({
    required this.fsqId,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
  });

  final String fsqId;
  final String name;
  final String category;
  final String address;
  final double lat;
  final double lng;
  final int distanceMeters;

  String get distanceLabel {
    final miles = distanceMeters / 1609.34;
    return miles < 0.1 ? '${distanceMeters}m' : '${miles.toStringAsFixed(1)} mi';
  }
}
