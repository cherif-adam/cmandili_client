import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../ai_search/presentation/ai_search/ai_search_screen.dart';

/// The white search box under the home header. Filters the restaurant list
/// as the customer types; the ✨ button on the right opens AI search, and
/// turns into a ✕ that clears the text once something is typed.
class HomeSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final double screenWidth;
  final double screenHeight;

  const HomeSearchField({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: screenHeight * 0.1,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.012,
      ),
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: screenWidth * 0.025,
              offset: Offset(0, screenHeight * 0.006),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: screenWidth * 0.038,
          ),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchRestaurants,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: screenWidth * 0.038,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.primary,
              size: screenWidth * 0.06,
            ),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: screenWidth * 0.05),
                    onPressed: onCleared,
                  )
                : Tooltip(
                    message: 'AI Search',
                    child: IconButton(
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF6C3DE1),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiSearchScreen(),
                        ),
                      ),
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.017,
            ),
          ),
        ),
      ),
    );
  }
}
