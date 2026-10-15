import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// The row of menu sections on a restaurant's page: Tout · Pizzas ·
/// Salades… The selected one is orange. 60 px high.
class MenuCategoryChips extends StatelessWidget {
  /// 'All' first, then the menu's own sections as the restaurant named them.
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const MenuCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories.elementAt(index);
          final isSelected = category == selected;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: FilterChip(
                label: Text(category == 'All'
                    ? AppLocalizations.of(context)!.filterAll
                    : category),
                showCheckmark: false,
                selected: isSelected,
                onSelected: (_) => onSelected(category),
                backgroundColor: Theme.of(context).cardColor,
                selectedColor: AppColors.foodPrimary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
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
