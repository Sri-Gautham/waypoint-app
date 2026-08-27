import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../placeholder_tab.dart';
import '../../widgets/app_bottom_nav.dart';
import 'activity_tab.dart';
import 'home_tab.dart';
import 'profile_tab.dart';

/// The app shell shown after sign-up: bottom-tab navigation around Home,
/// Trips, Balances, Activity, and Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.data});

  final OnboardingData data;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(data: widget.data, onOpenTrip: () => _showComingSoon('Trip detail')),
      const PlaceholderTab(
        icon: Icons.luggage_outlined,
        title: 'Trips',
        subtitle: 'Upcoming and past trips will live here.',
      ),
      const PlaceholderTab(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Balances',
        subtitle: 'Who owes who, and settling up, will live here.',
      ),
      const ActivityTab(),
      ProfileTab(data: widget.data),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tabIndex, children: tabs),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}
