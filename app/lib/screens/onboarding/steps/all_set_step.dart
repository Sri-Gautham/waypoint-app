import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AllSetStep extends StatelessWidget {
  const AllSetStep({super.key, required this.firstName, required this.onGetStarted});

  final String firstName;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            "You're all set, $firstName",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            "Your account is ready. Let's get you to your trips.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onGetStarted, child: const Text('Get started')),
          ),
        ],
      ),
    );
  }
}
