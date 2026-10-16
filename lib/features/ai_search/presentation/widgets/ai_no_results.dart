import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/ai_search_provider.dart';

/// A search ran but found nothing: grey "search off" icon and a message.
class AiNoResults extends StatelessWidget {
  final AiSearchState state;

  const AiNoResults({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = state.mode == AiSearchMode.image
        ? l10n.aiSearchNoResultsPhoto(state.imageResponse?.dishName ?? 'this dish')
        : l10n.aiSearchNoResultsText;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
