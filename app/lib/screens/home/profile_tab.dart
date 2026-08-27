import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../../theme/app_colors.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final address = [
      data.street,
      data.apt,
      data.city,
      [data.state, data.zip].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: Text(
                    data.initials,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.fullName.isEmpty ? 'Jamie Rivera' : data.fullName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _InfoRow(label: 'Email', value: data.email.isEmpty ? 'Not added yet' : data.email),
          _InfoRow(label: 'Phone', value: data.phone.isEmpty ? 'Not added yet' : data.phone),
          _InfoRow(label: 'Home address', value: address.isEmpty ? 'Not added yet' : address, showDivider: false),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.showDivider = true});

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: showDivider
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
