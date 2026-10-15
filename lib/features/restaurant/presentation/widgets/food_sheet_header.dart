import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/food_item.dart';

/// Top of the food customization sheet: the big rounded photo, then the
/// name with the price on the right, then the description.
class FoodSheetHeader extends StatelessWidget {
  final FoodItem item;

  const FoodSheetHeader({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: (item.imageUrl.isNotEmpty && item.imageUrl.startsWith('http'))
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.background,
                    child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                  ),
                )
              : Container(
                  width: double.infinity,
                  height: 250,
                  color: AppColors.background,
                  child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              CurrencyFormatter.formatPrice(item.clientPrice),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.foodPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          item.description,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
