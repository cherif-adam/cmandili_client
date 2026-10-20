import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/search_result.dart';
import 'confidence_badge.dart';

/// Above photo-search results: "Couscous identifié — 4 résultats" and a
/// HIGH / MEDIUM / LOW ConfidenceBadge. Nothing when no dish was found.
class AiDishBadge extends StatelessWidget {
  final AiImageSearchResponse response;

  const AiDishBadge({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    if (response.dishName == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu_rounded,
              size: 16, color: Color(0xFF6C3DE1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.aiSearchIdentified(
                response.dishName ?? '',
                response.results.length,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ConfidenceBadge(confidence: response.confidence),
        ],
      ),
    );
  }
}
