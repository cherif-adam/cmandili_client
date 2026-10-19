import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import 'customization_group.dart';
import 'option_row.dart';

/// One group of the food sheet ("Sauce au choix", "Suppléments"…): title
/// with an Obligatoire / Optionnel pill, "choose 1 / up to 3" helper, then
/// one OptionRow per choice. Flashes red when [highlighted] (the user
/// tried to add to cart without completing it).
class OptionGroupSection extends StatelessWidget {
  final CustomizationGroup group;
  final Set<String> selectedIds;
  final bool highlighted;
  final ValueChanged<CustomizationOption> onToggle;

  const OptionGroupSection({
    super.key,
    required this.group,
    required this.selectedIds,
    required this.highlighted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final String helperText;
    if (group.minSelections == group.maxSelections) {
      helperText = l10n.optionGroupSelectExact(group.minSelections);
    } else if (group.minSelections == 0) {
      helperText = l10n.optionGroupSelectUpTo(group.maxSelections);
    } else {
      helperText = l10n.optionGroupSelectRange(group.minSelections, group.maxSelections);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.error.withValues(alpha: 0.06) : Colors.transparent,
        border: Border.all(
          color: highlighted ? AppColors.error : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: group.isRequired
                      ? AppColors.foodPrimary.withValues(alpha: 0.12)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  group.isRequired ? l10n.optionGroupRequired : l10n.optionGroupOptional,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: group.isRequired ? AppColors.foodPrimaryDark : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 13,
              color: highlighted ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final option in group.options)
            OptionRow(
              name: option.name,
              price: option.price,
              isSelected: selectedIds.contains(option.id),
              isSingleSelect: group.maxSelections == 1,
              onTap: () => onToggle(option),
            ),
        ],
      ),
    );
  }
}
