import 'package:flutter/material.dart';

import '../models/trip.dart';
import 'trip_landscape.dart';

/// A trip's cover: a generated/fetched photo when one exists
/// (trip.coverImageBytes — see CoverGenerationService), otherwise the
/// illustrated [TripLandscape] palette every trip always has as a
/// fallback.
class TripCoverArt extends StatelessWidget {
  const TripCoverArt({super.key, required this.trip, this.borderRadius = 16});

  final Trip trip;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bytes = trip.coverImageBytes;
    if (bytes == null) {
      return TripLandscape(theme: trip.cover, borderRadius: borderRadius);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => TripLandscape(theme: trip.cover, borderRadius: borderRadius),
      ),
    );
  }
}
