import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/providers/nearby_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/delivery_fee.dart';
import '../../../../../core/utils/venue_hours.dart';
import '../../../../../core/widgets/shop_card/closed_photo_overlay.dart';
import '../../../../../core/widgets/shop_card/photo_pill.dart';
import '../../../../../core/widgets/shop_card/shop_info_item.dart';
import '../../../data/models/supermarket.dart';
import '../../supermarket_detail/supermarket_detail_screen.dart';

/// Green used by the supermarket cards (icons, "Ouvert").
const _green = Color(0xFF4CAF50);

/// A supermarket in the home list. Opens the supermarket's page.
///
///   Column
///   ├─ photo (Stack)
///   │   ├─ ClosedPhotoOverlay   when closed
///   │   ├─ top-left:     "🕒 35 min · 570 m"
///   │   └─ bottom-right: "★ 4.3 (80)"
///   └─ _SupermarketInfo   name · Ouvert, description, fee and minimum
class SupermarketCard extends ConsumerWidget {
  final Supermarket supermarket;
  final double screenWidth;
  final double screenHeight;

  const SupermarketCard({
    super.key,
    required this.supermarket,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = ref.watch(shopDistanceLabelProvider(
        (lat: supermarket.latitude, lng: supermarket.longitude)));
    final l = AppLocalizations.of(context)!;
    final placeholder = Theme.of(context).scaffoldBackgroundColor;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupermarketDetailScreen(supermarket: supermarket),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.025),
        decoration: BoxDecoration(
          // Same rules as RestaurantCard: theme colours for the card, white
          // pills with dark text over the photo.
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(screenWidth * 0.06),
                    topRight: Radius.circular(screenWidth * 0.06),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: supermarket.imageUrl,
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
                      child: const Icon(Icons.store),
                    ),
                  ),
                ),

                if (!supermarket.isOpen)
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
                          color: _green,
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Text(
                          distance == null
                              ? '${supermarket.deliveryTime} min'
                              : '${supermarket.deliveryTime} min · $distance',
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
                          '${supermarket.rating}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth * 0.03,
                          ),
                        ),
                        Text(
                          ' (${supermarket.reviewCount})',
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
            _SupermarketInfo(
              supermarket: supermarket,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
          ],
        ),
      ),
    );
  }
}

/// Under the photo:
///   name ................. Ouvert
///   🕒 Ouvre à 08:00   (only when closed)
///   description
///   🛵 5,00 DT Livraison   🛍 20,00 DT Commande min.
class _SupermarketInfo extends StatelessWidget {
  final Supermarket supermarket;
  final double screenWidth;
  final double screenHeight;

  const _SupermarketInfo({
    required this.supermarket,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final onCard = Theme.of(context).colorScheme.onSurface;
    // "Ouvre à HH:MM" hint — null when open or when no hours are configured.
    final opensAt =
        supermarket.isOpen ? null : nextOpeningLabel(supermarket.openingTime);

    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  supermarket.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: onCard,
                  ),
                ),
              ),
              if (supermarket.isOpen)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  ),
                  child: Text(
                    l.shopOpen,
                    style: TextStyle(
                      color: _green,
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
            supermarket.description,
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
                iconColor: _green,
                // Platform flat rate — see supermarket_detail_screen.
                value: CurrencyFormatter.formatPrice(kFlatDeliveryFee),
                valueColor: onCard,
                label: l.deliveryLabel,
                screenWidth: screenWidth,
              ),
              SizedBox(width: screenWidth * 0.06),
              ShopInfoItem(
                icon: Icons.shopping_bag_outlined,
                iconColor: _green,
                value: CurrencyFormatter.formatPrice(supermarket.minimumOrder),
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
