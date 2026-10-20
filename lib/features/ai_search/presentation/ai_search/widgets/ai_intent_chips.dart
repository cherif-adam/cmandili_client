import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/search_result.dart';

/// Above text-search results: "✦ 3 résultats" and the filters the AI
/// understood as small purple chips (🍽 pizza, 🌶 Spicy, ≤ 20 DT…).
class AiIntentChips extends StatelessWidget {
  final AiTextSearchResponse response;

  const AiIntentChips({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final intent = response.intent;
    final chips = <String>[];
    if (intent.category != null && intent.category != 'general') {
      chips.add('🍽 ${intent.category}');
    }
    if (intent.keyword != null) chips.add('🔍 ${intent.keyword}');
    if (intent.spicy == true) chips.add('🌶 Spicy');
    if (intent.vegetarian == true) chips.add('🥦 Vegetarian');
    if (intent.maxPrice != null) {
      chips.add('≤ ${intent.maxPrice!.toStringAsFixed(0)} DT');
    }
    if (intent.deliveryTime == 'fast') chips.add('⚡ Fast');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                response.isFallback
                    ? Icons.info_outline_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: const Color(0xFF6C3DE1),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  response.isFallback
                      ? l10n.aiSearchFallbackMessage
                      : l10n.aiSearchResultCount(response.results.length),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          // Chips describe filters the fallback path deliberately dropped, so
          // showing them alongside relaxed results would misrepresent them.
          if (chips.isNotEmpty && !response.isFallback) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: chips
                  .map(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C3DE1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6C3DE1),
                              fontWeight: FontWeight.w500)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
