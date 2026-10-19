import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../data/models/grocery_category.dart';

/// The row of grocery filters on a supermarket's page:
/// 🛒 Tout · 🥬 Légumes · 🍎 Fruits · … — the selected one is green.
class GroceryCategoryChips extends StatelessWidget {
  /// Null = "Tout".
  final GroceryCategory? selected;
  final ValueChanged<GroceryCategory?> onChanged;

  const GroceryCategoryChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: GroceryCategory.values.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChip(
              category: null,
              label: AppLocalizations.of(context)!.filterAll,
              icon: '🛒',
              isSelected: selected == null,
              onChanged: onChanged,
            );
          }
          final category = GroceryCategory.values[index - 1];
          final lang = Localizations.localeOf(context).languageCode;
          return _CategoryChip(
            category: category,
            label: lang == 'fr'
                ? category.nameFr
                : lang == 'ar'
                    ? category.nameAr
                    : category.nameEn,
            icon: category.icon,
            isSelected: selected == category,
            onChanged: onChanged,
          );
        },
      ),
    );
  }
}

/// One filter: emoji + name. Tapping the selected one again goes back to
/// "Tout".
class _CategoryChip extends StatelessWidget {
  final GroceryCategory? category;
  final String label;
  final String icon;
  final bool isSelected;
  final ValueChanged<GroceryCategory?> onChanged;

  const _CategoryChip({
    required this.category,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        showCheckmark: false,
        selected: isSelected,
        onSelected: (selected) => onChanged(selected ? category : null),
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: const Color(0xFF4CAF50),
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
