import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Shared "Ta progression X/10 [====   ]" row + remaining/celebration text,
/// used by both the post-order sheet and the rewards screen.
class LoyaltyProgressSection extends StatelessWidget {
  final AppLocalizations l10n;
  final int filled;
  final int total;
  final String remainingText;

  const LoyaltyProgressSection({
    super.key,
    required this.l10n,
    required this.filled,
    required this.total,
    required this.remainingText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.loyaltyProgressLabel,
              style: const TextStyle(color: AppColors.loyaltyProgressLabelColor, fontSize: 13),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: filled.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) => Text(
                '${value.round()}/$total',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: filled / total),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, _) => Stack(
              children: [
                Container(height: 7, color: AppColors.loyaltyProgressTrack),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 7,
                    decoration: const BoxDecoration(gradient: AppColors.loyaltyProgressFillGradient),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          remainingText,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
        ),
      ],
    );
  }
}
