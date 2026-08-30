/// A place a member added to a trip's "Things to do nearby" list —
/// shared with the whole group via Supabase (see trip_places_service.dart).
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.fsqId,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    required this.addedByName,
  });

  /// The `trip_places` row id — needed to remove it later.
  final String id;
  final String fsqId;
  final String name;
  final String category;
  final String address;
  final double lat;
  final double lng;
  final String addedByName;

  factory SavedPlace.fromRow(Map<String, dynamic> row) => SavedPlace(
        id: row['id'] as String,
        fsqId: row['fsq_id'] as String,
        name: row['name'] as String,
        category: (row['category'] as String?) ?? '',
        address: (row['address'] as String?) ?? '',
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        addedByName: row['added_by_name'] as String,
      );
}
