import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.luggage_outlined, label: 'Trips'),
    (icon: Icons.account_balance_wallet_outlined, label: 'Balances'),
    (icon: Icons.notifications_outlined, label: 'Activity'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final color = selected ? context.colors.accent : context.colors.textTertiary;
              final item = _items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 21, color: color),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
