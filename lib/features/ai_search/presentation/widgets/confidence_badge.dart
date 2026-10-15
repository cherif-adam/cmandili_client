import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A small pill with how sure the AI is about the photo: green HIGH,
/// orange MEDIUM, grey otherwise.
class ConfidenceBadge extends StatelessWidget {
  final String confidence;

  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'high' => AppColors.success,
      'medium' => AppColors.warning,
      _ => AppColors.textLight,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        confidence.toUpperCase(),
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
