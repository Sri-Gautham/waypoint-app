import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

import '../../models/nearby_place.dart';
import '../../models/trip.dart';
import '../../services/auth_service.dart';
import '../../services/nearby_places_service.dart';
import '../../services/trip_places_service.dart';
import '../../theme/app_colors.dart';

enum _LoadState { loading, ready, geocodeFailed, searchFailed, noApiKey }

/// Browse things to do within 10 miles of [trip]'s destination, select
/// any number, and save them to the trip's shared list. Pops `true` if
/// anything was added (so the caller knows to refresh), else `false`/null.
class NearbyPlacesPickerScreen extends StatefulWidget {
  const NearbyPlacesPickerScreen({super.key, required this.trip, required this.alreadySavedFsqIds});

  final Trip trip;

  /// Places already on the trip's list — shown as disabled/checked so
  /// you can't add the same venue twice (the table's unique constraint
  /// would just no-op it anyway, but this is clearer in the UI).
  final Set<String> alreadySavedFsqIds;

  @override
  State<NearbyPlacesPickerScreen> createState() => _NearbyPlacesPickerScreenState();
}

class _NearbyPlacesPickerScreenState extends State<NearbyPlacesPickerScreen> {
  _LoadState _state = _LoadState.loading;
  List<NearbyPlace> _places = const [];
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    List<Location> locations;
    try {
      locations = await locationFromAddress(widget.trip.destination);
    } catch (_) {
      locations = const [];
    }
    if (locations.isEmpty) {
      if (!mounted) return;
      setState(() => _state = _LoadState.geocodeFailed);
      return;
    }
    final dest = locations.first;
    final result = await NearbyPlacesService.instance.searchNear(dest.latitude, dest.longitude);
    if (!mounted) return;
    if (!result.succeeded) {
      setState(() => _state = result.reason == NearbySearchUnavailableReason.noApiKey ? _LoadState.noApiKey : _LoadState.searchFailed);
      return;
    }
    setState(() {
      _places = result.places!;
      _state = _LoadState.ready;
    });
  }

  void _toggle(String fsqId) {
    if (widget.alreadySavedFsqIds.contains(fsqId)) return;
    setState(() {
      if (!_selected.add(fsqId)) _selected.remove(fsqId);
    });
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    String addedByName = 'You';
    try {
      final profile = await AuthService.instance.loadProfile();
      if (profile.fullName.isNotEmpty) addedByName = profile.fullName;
    } catch (_) {
      // fall back to 'You'
    }
    final toAdd = _places.where((p) => _selected.contains(p.fsqId));
    var anySucceeded = false;
    for (final place in toAdd) {
      final ok = await TripPlacesService.instance.addPlace(tripId: widget.trip.id, place: place, addedByName: addedByName);
      if (ok) anySucceeded = true;
    }
    if (!mounted) return;
    Navigator.of(context).pop(anySucceeded);
  }

  Widget _body() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.geocodeFailed:
        return _ErrorState(message: "Couldn't find ${widget.trip.destination} on the map.", onRetry: _load);
      case _LoadState.noApiKey:
        return const _ErrorState(message: 'Nearby search isn’t set up yet.', onRetry: null);
      case _LoadState.searchFailed:
        return _ErrorState(message: "Couldn't load nearby places. Check your connection and try again.", onRetry: _load);
      case _LoadState.ready:
        if (_places.isEmpty) {
          return const _ErrorState(message: 'No nearby places found.', onRetry: null);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          itemCount: _places.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) {
            final place = _places[i];
            final alreadySaved = widget.alreadySavedFsqIds.contains(place.fsqId);
            final selected = alreadySaved || _selected.contains(place.fsqId);
            return CheckboxListTile(
              value: selected,
              onChanged: alreadySaved ? null : (_) => _toggle(place.fsqId),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.accent,
              title: Text(place.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              subtitle: Text(
                alreadySaved ? '${place.category} · Already saved' : '${place.category} · ${place.distanceLabel} · ${place.address}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Things to do nearby', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(child: _body()),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ElevatedButton(
                  onPressed: _saving ? null : _addSelected,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Add ${_selected.length} selected'),
                ),
              ),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
