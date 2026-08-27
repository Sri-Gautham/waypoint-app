import 'package:flutter/material.dart';

import '../models/trip.dart';
import 'trip_cover_art.dart';

/// The illustrated trip card used on the Home dashboard and in the Trips
/// tab's Upcoming list: landscape art, name, destination/date, and an
/// overlapping avatar stack.
class TripHeroCard extends StatelessWidget {
  const TripHeroCard({super.key, required this.trip, required this.onTap, this.eyebrow, this.height = 168});

  final Trip trip;
  final VoidCallback onTap;
  final String? eyebrow;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        height: height,
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
                  colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.78)],
                  stops: const [0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    Text(
                      eyebrow!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    trip.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        '${trip.destination} · ${trip.dateLabel}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final (i, member) in trip.members.take(2).indexed)
                        Transform.translate(
                          offset: Offset(i == 0 ? 0 : -8.0 * i, 0),
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              member.initials,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      if (trip.members.length > 2)
                        Transform.translate(
                          offset: const Offset(-16, 0),
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              '+${trip.members.length - 2}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
