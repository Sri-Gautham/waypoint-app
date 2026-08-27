import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../theme/app_colors.dart';
import '../../widgets/trip_landscape.dart';
import 'chat_screen.dart';

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.trip});

  final Trip trip;

  void _openChat(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(trip: trip)));
  }

  void _startNavigation(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("This would open your maps app for turn-by-turn directions.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: AppColors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openChat(context),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TripLandscape(theme: trip.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.7)],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text('${trip.daysLeft}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.1)),
                          const Text('days left', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              '${trip.destination} · ${trip.dateLabel}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 19, top: 3),
                          child: Text(
                            'ETA ${trip.etaLabel}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _startNavigation(context),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.navigation_outlined, size: 18, color: Colors.white),
                        SizedBox(height: 2),
                        Text('Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text('Get directions', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 18, color: Color(0xFFCB9A2E)),
                        const SizedBox(height: 2),
                        Text(trip.weatherTemp, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text(trip.weatherCondition, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text('${trip.members.length + 1} total', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            _MemberRow(name: 'You (Admin)', initials: 'ME', status: MemberStatus.admin, distance: '—'),
            for (final member in trip.members)
              _MemberRow(name: member.name, initials: member.initials, status: member.status, distance: member.distance),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.name, required this.initials, required this.status, required this.distance});

  final String name;
  final String initials;
  final MemberStatus status;
  final String distance;

  (Color, Color, String) get _badge {
    switch (status) {
      case MemberStatus.admin:
        return (AppColors.accentTint, AppColors.accent, 'Admin');
      case MemberStatus.member:
        return (AppColors.successBg, AppColors.success, 'Member');
      case MemberStatus.invited:
        return (AppColors.pendingBg, AppColors.textSecondary, 'Invited');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _badge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
            child: Text(initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
                    ),
                  ],
                ),
                Text('$distance from home', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
