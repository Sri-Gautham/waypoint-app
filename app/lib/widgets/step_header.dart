import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Back button + "N / total" step counter shared by multi-step flows
/// (defaults to a 4-step flow to match onboarding's original steps).
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.onBack, this.total = 4});

  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (onBack != null)
          _CircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack!)
        else
          const SizedBox(width: 36, height: 36),
        Text(
          '$step / $total',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentTint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
