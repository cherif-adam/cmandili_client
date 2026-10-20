import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// A big tappable option at the top of the address picker:
///   (icon)  Title
///           subtitle ............................ › (or a spinner)
class AddressOptionCard extends StatelessWidget {
  final IconData icon;

  /// Icon colour; its light tint is the icon's background.
  final Color color;
  final double iconBackgroundAlpha;
  final String title;
  final String subtitle;

  /// Shows a spinner instead of the arrow.
  final bool loading;

  /// Null disables the tap (e.g. while loading).
  final VoidCallback? onTap;

  const AddressOptionCard({
    super.key,
    required this.icon,
    required this.color,
    required this.iconBackgroundAlpha,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: iconBackgroundAlpha),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
