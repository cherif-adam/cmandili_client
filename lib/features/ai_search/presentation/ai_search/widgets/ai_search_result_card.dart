import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/shop_card/closed_photo_overlay.dart';
import '../../../data/models/search_result.dart';

/// Card displaying a single food item from an AI search result.
/// Shows the dish image, name, price, restaurant, and smart badges (spicy, veg, etc).
/// A closed shop's dish gets the home screen's dim and « Fermé » on its photo.
/// The card has no add button: nothing is ordered from the search list.
class AiSearchResultCard extends StatelessWidget {
  final AiSearchFoodResult item;

  const AiSearchResultCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = item.discountPrice != null &&
        item.discountPrice! < item.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Food Image ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 110,
                    height: 110,
                    color: Colors.grey[100],
                    child: const Icon(Icons.restaurant_rounded,
                        color: AppColors.textLight, size: 32),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 110,
                    height: 110,
                    color: Colors.grey[100],
                    child: const Icon(Icons.restaurant_rounded,
                        color: AppColors.textLight, size: 32),
                  ),
                ),
                // Before the discount badge, which stays visible above the
                // dim (same order as the home screen's shop cards).
                if (!item.restaurantIsOpen)
                  ClosedPhotoOverlay(
                    label: AppLocalizations.of(context)!.shopClosed,
                    screenWidth: MediaQuery.of(context).size.width,
                    screenHeight: MediaQuery.of(context).size.height,
                    // The ClipRRect above already rounds the photo.
                    borderRadius: BorderRadius.zero,
                  ),
                // Discount badge overlay
                if (hasDiscount)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-${(((item.price - item.discountPrice!) / item.price) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Restaurant name
                  Row(
                    children: [
                      const Icon(Icons.store_rounded,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.restaurantName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Attribute badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.isSpicy)
                        _Badge(AppLocalizations.of(context)!.aiChipSpicy,
                            AppColors.error),
                      if (item.isVegetarian)
                        _Badge(AppLocalizations.of(context)!.aiBadgeVeg,
                            AppColors.success),
                      _Badge(
                        '⏱ ${item.preparationTime} min',
                        AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.effectivePrice.toStringAsFixed(1)} DT',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 4),
                            Text(
                              item.price.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Restaurant rating. 0 means "no review yet" (the
                      // column defaults to 0 until the first order rating),
                      // so it is hidden, as on the shop cards.
                      if ((item.restaurantRating ?? 0) > 0)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: AppColors.star),
                            const SizedBox(width: 2),
                            Text(
                              item.restaurantRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
