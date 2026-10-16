import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/new_item_badge.dart';
import '../../data/models/food_item.dart';
import 'food_item_customization_sheet.dart';

/// One dish on a restaurant's menu. Tapping it opens the options sheet
/// ([FoodItemCustomizationSheet]) to add it to the cart.
///
///   Row
///   ├─ _DishImage
///   └─ Column
///       ├─ Row: name ...... NOUVEAU · 🌿 (vegetarian)
///       ├─ description (2 lines)
///       └─ Row: _DishPrice ............ ⊕
class FoodItemCard extends ConsumerWidget {
  final FoodItem foodItem;
  // Open/closed state of the parent restaurant — gates add-to-cart (P0).
  final bool isOpen;

  const FoodItemCard({super.key, required this.foodItem, required this.isOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFoodItemSheet(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _DishImage(imageUrl: foodItem.imageUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              foodItem.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (foodItem.isNew) ...[
                            const SizedBox(width: 6),
                            const NewItemBadge(),
                            const SizedBox(width: 4),
                          ],
                          if (foodItem.isVegetarian) const _VegetarianIcon(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        foodItem.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _DishPrice(foodItem: foodItem)),
                          const _AddIcon(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFoodItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodItemCustomizationSheet(item: foodItem, isOpen: isOpen),
    );
  }
}

/// The 110×110 dish photo, or a food icon when there is none.
class _DishImage extends StatelessWidget {
  final String imageUrl;

  const _DishImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: (imageUrl.isNotEmpty && imageUrl.startsWith('http'))
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
            )
          : Container(
              width: 110,
              height: 110,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Icon(Icons.fastfood, color: Colors.grey),
            ),
    );
  }
}

/// The price. During a Happy Hour: [HH] new price, old price crossed out.
class _DishPrice extends StatelessWidget {
  final FoodItem foodItem;

  const _DishPrice({required this.foodItem});

  @override
  Widget build(BuildContext context) {
    // No end date = runs until the shop stops it; the cart charges the
    // discount either way, so the menu must show it either way too.
    final hhActive = foodItem.discountPrice != null &&
        (foodItem.discountEndTime == null ||
            foodItem.discountEndTime!.isAfter(DateTime.now()));

    if (!hhActive) {
      return Text(
        CurrencyFormatter.formatPrice(foodItem.clientPrice),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.foodPrimary,
        ),
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'HH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          CurrencyFormatter.formatPrice(foodItem.clientPrice),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF9500),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            CurrencyFormatter.formatPrice(foodItem.price),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Small green leaf in a circle: the dish is vegetarian.
class _VegetarianIcon extends StatelessWidget {
  const _VegetarianIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.eco,
        size: 16,
        color: AppColors.success,
      ),
    );
  }
}

/// The orange "+" square on the right of the price.
class _AddIcon extends StatelessWidget {
  const _AddIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.foodPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.add,
        color: AppColors.foodPrimary,
        size: 20,
      ),
    );
  }
}
