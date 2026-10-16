import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

/// One choice in an option group: radio (single choice) or checkbox
/// (multiple), the name, and "+1,500 DT" on the right.
class OptionRow extends StatelessWidget {
  final String name;
  final double price;
  final bool isSelected;
  final bool isSingleSelect;
  final VoidCallback onTap;

  const OptionRow({
    super.key,
    required this.name,
    required this.price,
    required this.isSelected,
    required this.isSingleSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrice = price;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isSingleSelect
                  ? (isSelected ? Icons.radio_button_checked : Icons.radio_button_off)
                  : (isSelected ? Icons.check_box : Icons.check_box_outline_blank),
              color: isSelected ? AppColors.foodPrimary : AppColors.textLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              displayPrice > 0
                  ? '+${CurrencyFormatter.formatPrice(displayPrice)}'
                  : CurrencyFormatter.formatPrice(displayPrice),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: displayPrice > 0 ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
