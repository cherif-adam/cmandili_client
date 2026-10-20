import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import 'example_query_tile.dart';

/// Before any search: big purple ✦ circle, title, explanation, then three
/// example queries and a "search with a photo" tile.
class AiEmptyState extends StatelessWidget {
  final double screenWidth;

  /// Called with the example text when an example query is tapped.
  final ValueChanged<String> onExampleQuery;
  final VoidCallback onPhotoTap;

  const AiEmptyState({
    super.key,
    required this.screenWidth,
    required this.onExampleQuery,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3DE1), Color(0xFF8F57FB)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3DE1).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.aiSearchEmptyTitle,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aiSearchEmptyDescription,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 32),
          // Example queries
          ExampleQueryTile(
            emoji: '🌯',
            text: '"${l10n.aiSearchExampleQuery1}"',
            onTap: () => onExampleQuery(l10n.aiSearchExampleQuery1),
          ),
          const SizedBox(height: 10),
          ExampleQueryTile(
            emoji: '🍕',
            text: '"${l10n.aiSearchExampleQuery2}"',
            onTap: () => onExampleQuery(l10n.aiSearchExampleQuery2),
          ),
          const SizedBox(height: 10),
          ExampleQueryTile(
            emoji: '🥙',
            text: '"${l10n.aiSearchExampleQuery3}"',
            onTap: () => onExampleQuery(l10n.aiSearchExampleQuery3),
          ),
          const SizedBox(height: 10),
          ExampleQueryTile(
            emoji: '📸',
            text: l10n.aiSearchExampleQueryPhoto,
            onTap: onPhotoTap,
            isImageOption: true,
          ),
        ],
      ),
    );
  }
}
