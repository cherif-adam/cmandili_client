import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// When the search could not answer: a calm empty state — a grey icon, the
/// message, and a quiet "Réessayer" that runs the same search again.
///
/// It used to be a red error block printing whatever the server sent, which
/// is how Gemini's 429 JSON ended up on the customer's screen. The message is
/// now always one of the screen's own sentences.
class AiErrorView extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback onRetry;

  const AiErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.aiSearchTryAgain),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF6C3DE1)),
          ),
        ],
      ),
    );
  }
}
