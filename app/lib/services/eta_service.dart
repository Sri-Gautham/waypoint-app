import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EtaUnavailableReason {
  permissionDenied,
  locationServicesOff,
  locationFailed,
  geocodeFailed,
  notSignedIn,
  syncFailed,
}

class EtaResult {
  const EtaResult.value(int minutes) : etaMinutes = minutes, reason = null;
  const EtaResult.unavailable(this.reason) : etaMinutes = null;

  final int? etaMinutes;
  final EtaUnavailableReason? reason;
  bool get succeeded => etaMinutes != null;
}

class MemberEta {
  const MemberEta({required this.displayName, required this.etaMinutes, required this.computedAt});
  final String displayName;
  final int etaMinutes;
  final DateTime computedAt;
}

/// Ad-hoc (not persistent/background-tracked) member ETA sharing for the
/// day of a trip. A member's ETA is only as fresh as the last time they
/// opened the trip and tapped to share it — no continuous location
/// tracking, so no battery cost between opens.
///
/// iOS gets a real driving-time estimate via Apple's MapKit (see
/// ios/Runner/EtaBridge.swift); Android falls back to a straight-line-
/// distance + rough-average-speed estimate (no MapKit equivalent there).
/// Cross-member visibility goes through Supabase's `trip_day_status`
/// table — see PROGRESS.md for why this is the one piece of trip data
/// that's actually backend-synced so far.
class EtaService {
  EtaService._();
  static final instance = EtaService._();

  static const _channel = MethodChannel('com.srigautham.waypoint/eta');

  SupabaseClient get _client => Supabase.instance.client;

  Future<int?> _drivingEtaMinutesIOS(Position from, Location to) async {
    try {
      final seconds = await _channel.invokeMethod<double>('drivingEtaSeconds', {
        'fromLat': from.latitude,
        'fromLng': from.longitude,
        'toLat': to.latitude,
        'toLng': to.longitude,
      });
      if (seconds == null) return null;
      return (seconds / 60).round();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  int _straightLineEtaMinutes(Position from, Location to) {
    final meters = Geolocator.distanceBetween(from.latitude, from.longitude, to.latitude, to.longitude);
    const assumedKmh = 70.0; // rough mixed city/highway average
    final hours = (meters / 1000) / assumedKmh;
    final minutes = (hours * 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  /// Computes the signed-in user's ETA to [destination] and shares it so
  /// every other member can see it. Every failure mode (permission,
  /// location services off, geocoding, not signed in, sync) is reported
  /// via [EtaResult.reason] rather than throwing — this runs from a
  /// button tap, not somewhere a crash would be acceptable.
  Future<EtaResult> computeAndShareMyEta({
    required String tripId,
    required String destination,
    required String displayName,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const EtaResult.unavailable(EtaUnavailableReason.permissionDenied);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const EtaResult.unavailable(EtaUnavailableReason.locationServicesOff);
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return const EtaResult.unavailable(EtaUnavailableReason.locationFailed);
    }

    List<Location> locations;
    try {
      locations = await locationFromAddress(destination);
    } catch (_) {
      locations = const [];
    }
    if (locations.isEmpty) {
      return const EtaResult.unavailable(EtaUnavailableReason.geocodeFailed);
    }
    final dest = locations.first;

    int etaMinutes;
    if (Platform.isIOS) {
      etaMinutes = await _drivingEtaMinutesIOS(position, dest) ?? _straightLineEtaMinutes(position, dest);
    } else {
      etaMinutes = _straightLineEtaMinutes(position, dest);
    }

    final user = _client.auth.currentUser;
    if (user == null) return const EtaResult.unavailable(EtaUnavailableReason.notSignedIn);
    try {
      await _client.from('trip_day_status').upsert({
        'trip_id': tripId,
        'user_id': user.id,
        'display_name': displayName,
        'eta_minutes': etaMinutes,
        'computed_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      return const EtaResult.unavailable(EtaUnavailableReason.syncFailed);
    }

    return EtaResult.value(etaMinutes);
  }

  /// Every member's last-shared ETA for this trip. Empty (never throws)
  /// if the fetch fails — the UI just shows "not shared yet" for
  /// everyone in that case.
  Future<List<MemberEta>> fetchEtas(String tripId) async {
    try {
      final rows = await _client.from('trip_day_status').select().eq('trip_id', tripId);
      return (rows as List).map((row) {
        final r = row as Map<String, dynamic>;
        return MemberEta(
          displayName: r['display_name'] as String,
          etaMinutes: r['eta_minutes'] as int,
          computedAt: DateTime.parse(r['computed_at'] as String),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
