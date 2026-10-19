import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/providers/nearby_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/cuisine_labels.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/delivery_fee.dart';
import '../../../../core/utils/venue_hours.dart';
import '../../../../core/widgets/shop_card/closed_photo_overlay.dart';
import '../../../../core/widgets/shop_card/photo_pill.dart';
import '../../../../core/widgets/shop_card/shop_info_item.dart';
import '../../../home/data/models/restaurant.dart';
import '../restaurant_detail/restaurant_detail_screen.dart';

/// A restaurant in the home list (also used by the favourites). Opens the
/// restaurant's page.
///
///   Column
///   ├─ photo (Stack)
///   │   ├─ ClosedPhotoOverlay   when closed
///   │   ├─ top-left:     "🕒 25 min · 640 m"
///   │   ├─ top-right:    "Nouveau"   (first week)
///   │   ├─ bottom-left:  cuisine, e.g. "Pizza"
///   │   └─ bottom-right: "★ 4.6 (214)"
///   └─ _RestaurantInfo     name · Ouvert, description, fee and minimum
class RestaurantCard extends ConsumerWidget {
  final Restaurant restaurant;

  const RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = ref.watch(shopDistanceLabelProvider(
        (lat: restaurant.latitude, lng: restaurant.longitude)));
    final l = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        );
        // If result is 2, it means user wants to view cart
        if (result == 2 && context.mounted) {
          // Find the home screen and switch to cart tab
          // This will be handled by the home screen's state
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.025),
        decoration: BoxDecoration(
          // Card and text follow the theme; the pills over the photo stay
          // white with dark text in both themes.
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: screenWidth * 0.038,
              offset: Offset(0, screenHeight * 0.006),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'restaurant_image_${restaurant.id}',
              child: Stack(
                children: [
                  _RestaurantPhoto(
                    imageUrl: restaurant.imageUrl,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),

                  // Placed before the pills so they stay visible above the dim.
                  if (!restaurant.isOpen)
                    ClosedPhotoOverlay(
                      label: l.shopClosed,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),

                  // Delivery time and distance
                  Positioned(
                    top: screenHeight * 0.02,
                    left: screenWidth * 0.04,
                    child: PhotoPill(
                      color: Colors.white.withValues(alpha: 0.9),
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            size: screenWidth * 0.035,
                            color: restaurant.isOpen ? AppColors.success : AppColors.error,
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            distance == null
                                ? '${restaurant.deliveryTime} min'
                                : '${restaurant.deliveryTime} min · $distance',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // "Nouveau" — venues added within the last 7 days.
                  if (restaurant.isNew)
                    Positioned(
                      top: screenHeight * 0.02,
                      right: screenWidth * 0.04,
                      child: PhotoPill(
                        color: AppColors.success,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        child: Text(
                          l.newShopBadge,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.03,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // First cuisine, e.g. "Pâtisseries"
                  if (restaurant.categories.isNotEmpty)
                    Positioned(
                      bottom: screenHeight * 0.02,
                      left: screenWidth * 0.04,
                      child: PhotoPill(
                        color: Colors.white,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              restaurant.categories.first == 'Pâtisseries'
                                  ? Icons.cake_rounded
                                  : Icons.restaurant_menu_rounded,
                              size: screenWidth * 0.035,
                              color: AppColors.foodPrimary,
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              cuisineLabel(l, restaurant.categories.first),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Rating
                  Positioned(
                    bottom: screenHeight * 0.02,
                    right: screenWidth * 0.04,
                    child: PhotoPill(
                      color: Colors.white,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: screenWidth * 0.04,
                            color: AppColors.star,
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            '${restaurant.rating}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.03,
                            ),
                          ),
                          Text(
                            ' (${restaurant.reviewCount})',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                              fontSize: screenWidth * 0.03,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _RestaurantInfo(
              restaurant: restaurant,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo, or a restaurant icon when there is none.
class _RestaurantPhoto extends StatelessWidget {
  final String imageUrl;
  final double screenWidth;
  final double screenHeight;

  const _RestaurantPhoto({
    required this.imageUrl,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).scaffoldBackgroundColor;
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(screenWidth * 0.06),
        topRight: Radius.circular(screenWidth * 0.06),
      ),
      child: (imageUrl.isNotEmpty && imageUrl.startsWith('http'))
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              height: screenHeight * 0.25,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: placeholder,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: placeholder,
                child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
              ),
            )
          : Container(
              height: screenHeight * 0.25,
              width: double.infinity,
              color: placeholder,
              child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
            ),
    );
  }
}

/// Under the photo:
///   name ................. Ouvert
///   🕒 Ouvre à 18:00   (only when closed)
///   description
///   🛵 3,50 DT Livraison   🛍 10,00 DT Commande min.
class _RestaurantInfo extends StatelessWidget {
  final Restaurant restaurant;
  final double screenWidth;
  final double screenHeight;

  const _RestaurantInfo({
    required this.restaurant,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final onCard = Theme.of(context).colorScheme.onSurface;
    // "Ouvre à HH:MM" hint — null when open or when no hours are configured.
    final opensAt =
        restaurant.isOpen ? null : nextOpeningLabel(restaurant.openingTime);

    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expanded: a long name ends in "…" instead of pushing
              // the "Ouvert" badge off the card.
              Expanded(
                child: Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: onCard,
                  ),
                ),
              ),
              if (restaurant.isOpen)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  ),
                  child: Text(
                    l.shopOpen,
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: screenWidth * 0.03,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (opensAt != null) ...[
            SizedBox(height: screenHeight * 0.006),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: screenWidth * 0.035,
                  color: AppColors.error,
                ),
                SizedBox(width: screenWidth * 0.015),
                Text(
                  opensAt,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: screenWidth * 0.032,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: screenHeight * 0.01),
          Text(
            restaurant.description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: screenWidth * 0.035,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Row(
            children: [
              ShopInfoItem(
                icon: Icons.delivery_dining_outlined,
                iconColor: AppColors.foodPrimary,
                // restaurant.deliveryFee is the DB's dead
                // restaurants.delivery_fee column (0 for every restaurant —
                // the fee is distance-based, see delivery_fee.dart). Show
                // the real base fee rather than a stale zero.
                value: CurrencyFormatter.formatPrice(kDeliveryBaseFee),
                valueColor: onCard,
                label: l.deliveryLabel,
                screenWidth: screenWidth,
              ),
              SizedBox(width: screenWidth * 0.06),
              ShopInfoItem(
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.foodPrimary,
                value: CurrencyFormatter.formatPrice(restaurant.minimumOrder),
                valueColor: onCard,
                label: l.minOrderLabel,
                screenWidth: screenWidth,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
