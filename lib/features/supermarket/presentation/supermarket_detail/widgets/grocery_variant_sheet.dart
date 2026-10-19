import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../menu/data/models/item_variant.dart';
import '../../../data/models/grocery_item.dart';

/// Opens [GroceryVariantSheet] and returns the option picked, or null if
/// the customer closed it.
Future<ItemVariant?> showGroceryVariantSheet(
  BuildContext context,
  GroceryItem item,
  List<ItemVariant> variants,
) {
  return showModalBottomSheet<ItemVariant>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => GroceryVariantSheet(item: item, variants: variants),
  );
}

/// "Choisissez une option": one row per variant (e.g. 1 L / 2 L) with its
/// price. Tapping a row closes the sheet with that variant.
class GroceryVariantSheet extends StatelessWidget {
  final GroceryItem item;
  final List<ItemVariant> variants;

  const GroceryVariantSheet({super.key, required this.item, required this.variants});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.chooseAnOption,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final v in variants)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.radio_button_unchecked,
                    color: Color(0xFF4CAF50)),
                title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  CurrencyFormatter.formatPrice(v.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                    fontSize: 15,
                  ),
                ),
                onTap: () => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    );
  }
}
