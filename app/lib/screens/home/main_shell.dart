import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../../widgets/app_bottom_nav.dart';
import '../balances/balances_tab.dart';
import '../trips/trips_tab.dart';
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

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(data: widget.data),
      const TripsTab(),
      const BalancesTab(),
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
