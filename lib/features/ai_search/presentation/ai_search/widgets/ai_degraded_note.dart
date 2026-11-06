import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// Above results found WITHOUT the AI (status "degraded"): one small grey
/// line, so the customer knows why the list may be rougher than usual. The
/// results themselves are shown normally — this is not an error.
class AiDegradedNote extends StatelessWidget {
  const AiDegradedNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.textLight),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.aiSearchDegradedNote,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
