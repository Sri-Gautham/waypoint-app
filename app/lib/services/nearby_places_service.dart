import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/foursquare_config.dart';
import '../models/nearby_place.dart';

enum NearbySearchUnavailableReason { noApiKey, geocodeFailed, locationFailed, requestFailed }

class NearbySearchResult {
  const NearbySearchResult.places(this.places) : reason = null;
  const NearbySearchResult.unavailable(this.reason) : places = null;

  final List<NearbyPlace>? places;
  final NearbySearchUnavailableReason? reason;
  bool get succeeded => places != null;
}

/// "Things to do nearby" — searches Foursquare's Places API within a 10
/// mile radius. No AI/generation involved, just a real venue search, so
/// there's no iOS/Android split like cover generation or receipt OCR
/// needed here — one HTTP call works the same on both platforms.
class NearbyPlacesService {
  NearbyPlacesService._();
  static final instance = NearbyPlacesService._();

  static const _radiusMeters = 16093; // 10 miles

  Future<NearbySearchResult> searchNear(double lat, double lng) async {
    if (FoursquareConfig.apiKey.isEmpty) {
      return const NearbySearchResult.unavailable(NearbySearchUnavailableReason.noApiKey);
    }
    try {
      final uri = Uri.https('api.foursquare.com', '/v3/places/search', {
        'll': '$lat,$lng',
        'radius': '$_radiusMeters',
        'limit': '30',
        'sort': 'RELEVANCE',
        'fields': 'fsq_id,name,categories,location,geocodes,distance',
      });
      final response = await http.get(
        uri,
        headers: {'Authorization': FoursquareConfig.apiKey, 'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        return const NearbySearchResult.unavailable(NearbySearchUnavailableReason.requestFailed);
      }
      final results = (jsonDecode(response.body) as Map<String, dynamic>)['results'] as List<dynamic>;
      final places = results.map((r) {
        final row = r as Map<String, dynamic>;
        final categories = row['categories'] as List<dynamic>? ?? const [];
        final category = categories.isNotEmpty ? (categories.first as Map<String, dynamic>)['name'] as String : 'Place';
        final location = row['location'] as Map<String, dynamic>? ?? const {};
        final geocodes = row['geocodes'] as Map<String, dynamic>? ?? const {};
        final main = geocodes['main'] as Map<String, dynamic>? ?? const {};
        return NearbyPlace(
          fsqId: row['fsq_id'] as String,
          name: row['name'] as String,
          category: category,
          address: (location['formatted_address'] as String?) ?? '',
          lat: (main['latitude'] as num?)?.toDouble() ?? lat,
          lng: (main['longitude'] as num?)?.toDouble() ?? lng,
          distanceMeters: (row['distance'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      return NearbySearchResult.places(places);
    } catch (_) {
      return const NearbySearchResult.unavailable(NearbySearchUnavailableReason.requestFailed);
    }
  }
}
