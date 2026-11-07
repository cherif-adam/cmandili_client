import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import 'twinkling_sparkle.dart';

/// "Chercher « <text> » avec l'IA ✦": offered where the restaurant filter
/// found nothing for what was typed. Tapping it opens Recherche IA with the
/// text already searched ([onTap]).
class AskAiSearchRow extends StatelessWidget {
  const AskAiSearchRow({super.key, required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: AppColors.aiViolet.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              TwinklingSparkle(size: 20, animate: !reduceMotion),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.aiSearchWithAi(query),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.aiViolet,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.aiViolet),
            ],
          ),
        ),
      ),
    );
  }
}
