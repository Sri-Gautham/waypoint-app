import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/activity_log_entry.dart';
import '../../models/saved_place.dart';
import '../../models/trip.dart';
import '../../models/trip_photo.dart';
import '../../services/trip_places_service.dart';
import '../../state/app_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/trip_cover_art.dart';
import '../../widgets/trip_hero_card.dart';
import '../trip/trip_detail_screen.dart';
import 'nearby_places_picker_screen.dart';
import 'photo_slideshow_screen.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  final _picker = ImagePicker();
  final Map<String, List<TripPhoto>> _photosByTrip = {};
  final Set<String> _expandedTripIds = {};
  final Map<String, List<SavedPlace>> _savedPlacesByTrip = {};
  final Set<String> _loadingPlacesFor = {};

  List<TripPhoto> _photosFor(String tripId) => _photosByTrip[tripId] ?? const [];
  List<SavedPlace> _placesFor(String tripId) => _savedPlacesByTrip[tripId] ?? const [];

  Future<void> _ensurePlacesLoaded(String tripId) async {
    if (_savedPlacesByTrip.containsKey(tripId) || _loadingPlacesFor.contains(tripId)) return;
    setState(() => _loadingPlacesFor.add(tripId));
    final places = await TripPlacesService.instance.fetchSavedPlaces(tripId);
    if (!mounted) return;
    setState(() {
      _savedPlacesByTrip[tripId] = places;
      _loadingPlacesFor.remove(tripId);
    });
  }

  Future<void> _browseNearby(Trip trip) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NearbyPlacesPickerScreen(
          trip: trip,
          alreadySavedFsqIds: _placesFor(trip.id).map((p) => p.fsqId).toSet(),
        ),
      ),
    );
    if (added == true) {
      _savedPlacesByTrip.remove(trip.id);
      await _ensurePlacesLoaded(trip.id);
    }
  }

  Future<void> _removePlace(String tripId, String placeId) async {
    final ok = await TripPlacesService.instance.removePlace(placeId);
    if (!ok || !mounted) return;
    setState(() {
      _savedPlacesByTrip[tripId] = _placesFor(tripId).where((p) => p.id != placeId).toList();
    });
  }

  Future<void> _navigateTo(SavedPlace place) async {
    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?daddr=${place.lat},${place.lng}')
        : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${place.lat},${place.lng}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open Maps.")));
    }
  }

  Future<void> _addPhoto(String tripId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      final list = List<TripPhoto>.from(_photosFor(tripId));
      list.add(TripPhoto(id: 'ph-${DateTime.now().microsecondsSinceEpoch}', file: File(picked.path), uploader: 'You'));
      _photosByTrip[tripId] = list;
    });
  }

  void _openSlideshow(Trip trip, {int startIndex = 0}) {
    final photos = _photosFor(trip.id);
    if (photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoSlideshowScreen(tripName: trip.name, photos: photos, initialIndex: startIndex),
      ),
    );
  }

  void _toggleExpanded(String tripId) {
    setState(() {
      if (_expandedTripIds.contains(tripId)) {
        _expandedTripIds.remove(tripId);
      } else {
        _expandedTripIds.add(tripId);
      }
    });
    if (_expandedTripIds.contains(tripId)) _ensurePlacesLoaded(tripId);
  }

  @override
  Widget build(BuildContext context) {
    final appData = AppDataScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trips', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          const _SectionLabel('Upcoming'),
          const SizedBox(height: 10),
          for (final trip in appData.upcoming) ...[
            _UpcomingTripCard(
              trip: trip,
              expanded: _expandedTripIds.contains(trip.id),
              places: _placesFor(trip.id),
              loadingPlaces: _loadingPlacesFor.contains(trip.id),
              onToggleExpand: () => _toggleExpanded(trip.id),
              onBrowseNearby: () => _browseNearby(trip),
              onRemovePlace: (p) => _removePlace(trip.id, p.id),
              onNavigate: _navigateTo,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          const _SectionLabel('Past'),
          const SizedBox(height: 10),
          for (final trip in appData.past)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PastTripCard(
                trip: trip,
                expanded: _expandedTripIds.contains(trip.id),
                photos: _photosFor(trip.id),
                totalSpend: (appData.chargesByTrip[trip.id] ?? const []).fold(0.0, (sum, c) => sum + c.amount),
                places: _placesFor(trip.id),
                loadingPlaces: _loadingPlacesFor.contains(trip.id),
                onToggleExpand: () => _toggleExpanded(trip.id),
                onPlay: () => _openSlideshow(trip),
                onOpenPhoto: (i) => _openSlideshow(trip, startIndex: i),
                onAddPhoto: () => _addPhoto(trip.id),
                onRemovePlace: (p) => _removePlace(trip.id, p.id),
                onNavigate: _navigateTo,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
    );
  }
}

class _PastTripCard extends StatelessWidget {
  const _PastTripCard({
    required this.trip,
    required this.expanded,
    required this.photos,
    required this.totalSpend,
    required this.places,
    required this.loadingPlaces,
    required this.onToggleExpand,
    required this.onPlay,
    required this.onOpenPhoto,
    required this.onAddPhoto,
    required this.onRemovePlace,
    required this.onNavigate,
  });

  final Trip trip;
  final bool expanded;
  final List<TripPhoto> photos;
  final double totalSpend;
  final List<SavedPlace> places;
  final bool loadingPlaces;
  final VoidCallback onToggleExpand;
  final VoidCallback onPlay;
  final ValueChanged<int> onOpenPhoto;
  final VoidCallback onAddPhoto;
  final ValueChanged<SavedPlace> onRemovePlace;
  final ValueChanged<SavedPlace> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggleExpand,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: trip.cover.accent, borderRadius: BorderRadius.circular(10)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text('${trip.destination} · ${trip.dateLabel}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Material(
                color: AppColors.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPlay,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const Padding(
              padding: EdgeInsets.only(top: 14, bottom: 12),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            _MemoryRecapCard(trip: trip, totalSpend: totalSpend, photoCount: photos.length),
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            _SectionLabel('Members'),
            const SizedBox(height: 8),
            _MemberList(trip: trip),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel('Photos'),
                Text(
                  photos.isEmpty ? 'No photos yet' : '${photos.length} photo${photos.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _PhotoGrid(photos: photos, onOpenPhoto: onOpenPhoto, onAddPhoto: onAddPhoto),
            const SizedBox(height: 18),
            _SectionLabel('Activity'),
            const SizedBox(height: 8),
            _ActivityLog(entries: trip.activityLog),
            const SizedBox(height: 18),
            _ThingsToDoSection(
              places: places,
              loading: loadingPlaces,
              onRemove: onRemovePlace,
              onNavigate: onNavigate,
              onBrowse: null, // no adding new plans to a trip that's already over
            ),
          ],
        ],
      ),
    );
  }
}

/// Upcoming trips list uses the existing illustrated [TripHeroCard] for
/// its collapsed state (unchanged tap-to-open-detail behavior) with a
/// separate "Details" toggle below it — distinct tap targets, since
/// overloading the hero card's own onTap would break the existing
/// navigate-to-detail behavior.
class _UpcomingTripCard extends StatelessWidget {
  const _UpcomingTripCard({
    required this.trip,
    required this.expanded,
    required this.places,
    required this.loadingPlaces,
    required this.onToggleExpand,
    required this.onBrowseNearby,
    required this.onRemovePlace,
    required this.onNavigate,
  });

  final Trip trip;
  final bool expanded;
  final List<SavedPlace> places;
  final bool loadingPlaces;
  final VoidCallback onToggleExpand;
  final VoidCallback onBrowseNearby;
  final ValueChanged<SavedPlace> onRemovePlace;
  final ValueChanged<SavedPlace> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: TripHeroCard(
            trip: trip,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
            ),
          ),
        ),
        InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  expanded ? 'Hide details' : 'Details',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
                Icon(
                  expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 1.5), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Members'),
                const SizedBox(height: 8),
                _MemberList(trip: trip),
                const SizedBox(height: 18),
                _ThingsToDoSection(
                  places: places,
                  loading: loadingPlaces,
                  onRemove: onRemovePlace,
                  onNavigate: onNavigate,
                  onBrowse: onBrowseNearby,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A trip's group-wide saved-places list — shared across members via
/// Supabase (see trip_places_service.dart). [onBrowse] is null for past
/// trips (view/remove only, no adding new plans after the fact).
class _ThingsToDoSection extends StatelessWidget {
  const _ThingsToDoSection({
    required this.places,
    required this.loading,
    required this.onRemove,
    required this.onNavigate,
    required this.onBrowse,
  });

  final List<SavedPlace> places;
  final bool loading;
  final ValueChanged<SavedPlace> onRemove;
  final ValueChanged<SavedPlace> onNavigate;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('Things to do nearby'),
            if (onBrowse != null)
              TextButton.icon(
                onPressed: onBrowse,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Browse'),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  foregroundColor: AppColors.accent,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (places.isEmpty)
          Text(
            onBrowse != null ? 'Nothing saved yet — browse nearby to add some.' : 'Nothing was saved for this trip.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          )
        else
          for (final place in places)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(
                          '${place.category} · added by ${place.addedByName}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onNavigate(place),
                    icon: const Icon(Icons.directions_rounded, size: 20, color: AppColors.accent),
                    tooltip: 'Navigate',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    onPressed: () => onRemove(place),
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                    tooltip: 'Remove',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// The post-trip recap: cover art, dates, and a couple of headline stats.
/// Appears automatically once a trip has ended — no separate "reveal"
/// moment, just always there when you expand a past trip.
class _MemoryRecapCard extends StatelessWidget {
  const _MemoryRecapCard({required this.trip, required this.totalSpend, required this.photoCount});

  final Trip trip;
  final double totalSpend;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TripCoverArt(trip: trip),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.75)],
                    stops: const [0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRIP MEMORIES',
                      style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${trip.destination} · ${trip.dateLabel}',
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Total spent', value: '\$${totalSpend.toStringAsFixed(2)}')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Photos', value: '$photoCount')),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.accentTint, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final member in [
          (name: 'You', initials: 'ME'),
          ...trip.members.map((m) => (name: m.name, initials: m.initials)),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                  child: Text(member.initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 8),
                Text(member.name, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onOpenPhoto, required this.onAddPhoto});

  final List<TripPhoto> photos;
  final ValueChanged<int> onOpenPhoto;
  final VoidCallback onAddPhoto;

  static const _crossAxisCount = 3;
  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = (constraints.maxWidth - _spacing * (_crossAxisCount - 1)) / _crossAxisCount;
        final tiles = <Widget>[
          for (final (i, photo) in photos.indexed)
            InkWell(
              onTap: () => onOpenPhoto(i),
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(photo.file, width: tileSize, height: tileSize, fit: BoxFit.cover),
              ),
            ),
          InkWell(
            onTap: onAddPhoto,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: tileSize,
              height: tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, size: 20, color: AppColors.textSecondary),
            ),
          ),
        ];
        return Wrap(spacing: _spacing, runSpacing: _spacing, children: tiles);
      },
    );
  }
}

class _ActivityLog extends StatelessWidget {
  const _ActivityLog({required this.entries});
  final List<ActivityLogEntry> entries;

  IconData _iconFor(ActivityLogKind kind) {
    switch (kind) {
      case ActivityLogKind.person:
        return Icons.person_outline_rounded;
      case ActivityLogKind.receipt:
        return Icons.receipt_long_outlined;
      case ActivityLogKind.photo:
        return Icons.image_outlined;
      case ActivityLogKind.chat:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.divider, shape: BoxShape.circle),
                  child: Icon(_iconFor(entry.kind), size: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.text, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4)),
                      Text(entry.time, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
