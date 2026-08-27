import 'package:flutter/material.dart';

import '../../models/activity_item.dart';
import '../../models/onboarding_data.dart';
import '../../state/app_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/trip_hero_card.dart';
import '../group/create_group_flow.dart';
import '../trip/trip_detail_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final appData = AppDataScope.of(context);
    final trip = appData.nextTrip;
    final firstName = data.firstName.isEmpty ? 'there' : data.firstName;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $firstName',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text("Here's what's coming up", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Text(
                  data.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TripHeroCard(
            trip: trip,
            eyebrow: 'NEXT TRIP',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGroupFlow()),
                  ),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: const Text('Create a group', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: const Text('Join with code', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          for (final item in ActivityItem.sample)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
                        const SizedBox(height: 2),
                        Text(item.time, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
