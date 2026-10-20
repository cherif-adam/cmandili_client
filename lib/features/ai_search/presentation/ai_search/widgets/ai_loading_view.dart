import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../providers/ai_search_provider.dart';
import 'ai_spinner.dart';

/// While searching: the purple AiSpinner, "Analyse de la photo…" (or of
/// the text) and a small "powered by" line.
class AiLoadingView extends StatelessWidget {
  final AiSearchMode mode;

  const AiLoadingView({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = mode == AiSearchMode.image
        ? l10n.aiSearchLoadingPhoto
        : l10n.aiSearchLoadingText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AiSpinner(),
          const SizedBox(height: 20),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 6),
          Text(l10n.aiSearchPoweredBy,
              style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
        ],
      ),
    );
  }
}
