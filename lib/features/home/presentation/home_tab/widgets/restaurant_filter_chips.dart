import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/cuisine_labels.dart';

/// The horizontal row of cuisine filters above the restaurant list:
/// Tout · Pâtisseries · Pizza · Burgers…  The selected one is orange.
class RestaurantFilterChips extends StatelessWidget {
  /// Canonical values (also stored in `restaurants.categories`); what is
  /// shown is their translation, see [cuisineLabel].
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  final double screenWidth;
  final double screenHeight;

  const RestaurantFilterChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: screenHeight * 0.075,
      margin: EdgeInsets.only(
        top: screenHeight * 0.012,
        bottom: screenHeight * 0.012,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;

          return Padding(
            padding: EdgeInsets.only(right: screenWidth * 0.03),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: FilterChip(
                label: Text(cuisineLabel(AppLocalizations.of(context)!, category)),
                showCheckmark: false,
                selected: isSelected,
                onSelected: (_) => onSelected(category),
                backgroundColor: Theme.of(context).cardColor,
                selectedColor: AppColors.foodPrimary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: screenWidth * 0.036,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenHeight * 0.01,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenWidth * 0.05),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.textLight.withValues(alpha: 0.2),
                  ),
                ),
                elevation: isSelected ? 4 : 0,
                shadowColor: AppColors.foodPrimary.withValues(alpha: 0.4),
              ),
            ),
          );
        },
      ),
    );
  }
}
