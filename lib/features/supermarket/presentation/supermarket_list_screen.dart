import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/providers/nearby_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/delivery_fee.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/venue_hours.dart';
import '../data/models/supermarket.dart';
import '../providers/supermarket_provider.dart';
import 'supermarket_detail_screen.dart';

class SupermarketListScreen extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const SupermarketListScreen({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  Widget _buildHeroBanner(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 110,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/amana_supermarket_hero.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.25),
                errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.emeraldBannerGradient),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)!.supermarketHeroTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supermarketsAsync = ref.watch(nearbySupermarketsProvider);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: screenHeight * 0.015),
            child: _buildHeroBanner(context),
          ),
        ),
        supermarketsAsync.when(
          data: (supermarkets) => supermarkets.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(screenHeight * 0.05),
                    child: Column(
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: screenWidth * 0.12, color: Colors.grey[400]),
                        SizedBox(height: screenHeight * 0.02),
                        Text(
                          AppLocalizations.of(context)!
                              .noSupermarketsNearby(kShopRadiusKm.round()),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.05,
              0,
              screenWidth * 0.05,
              screenHeight * 0.12,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final supermarket = supermarkets[index];
                  return _SupermarketCard(
                    supermarket: supermarket,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  );
                },
                childCount: supermarkets.length,
              ),
            ),
          ),
          loading: () => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(screenHeight * 0.05),
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
          error: (error, stack) => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(screenHeight * 0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    SizedBox(height: screenHeight * 0.02),
                    Text(AppLocalizations.of(context)!.couldNotLoadSupermarkets, style: const TextStyle(fontSize: 16)),
                    SizedBox(height: screenHeight * 0.02),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(supermarketsProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupermarketCard extends ConsumerWidget {
  final Supermarket supermarket;
  final double screenWidth;
  final double screenHeight;

  const _SupermarketCard({
    required this.supermarket,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = ref.watch(shopDistanceLabelProvider(
        (lat: supermarket.latitude, lng: supermarket.longitude)));
    final l = AppLocalizations.of(context)!;
    // Same rules as RestaurantCard: theme colours for the card, white pills
    // with dark text over the photo.
    final cardColor = Theme.of(context).cardColor;
    final onCard = Theme.of(context).colorScheme.onSurface;
    final placeholder = Theme.of(context).scaffoldBackgroundColor;
    // "Ouvre à HH:MM" hint — null when open or when no hours are configured.
    final opensAt =
        supermarket.isOpen ? null : nextOpeningLabel(supermarket.openingTime);

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
          color: cardColor,
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
            // Supermarket Image
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

                // Closed state: dim the image + centered "Fermé" pill.
                // Closed venues stay tappable — browsing is allowed, ordering
                // is blocked in the detail screen (ghost-order fix).
                if (!supermarket.isOpen)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(screenWidth * 0.06),
                        topRight: Radius.circular(screenWidth * 0.06),
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04,
                            vertical: screenHeight * 0.01,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(screenWidth * 0.06),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: screenWidth * 0.04,
                                color: Colors.white,
                              ),
                              SizedBox(width: screenWidth * 0.015),
                              Text(
                                l.shopClosed,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Delivery Time Badge
                Positioned(
                  top: screenHeight * 0.02,
                  left: screenWidth * 0.04,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.03,
                      vertical: screenHeight * 0.008,
                    ),
                    decoration: BoxDecoration(
                      // Same white pill as the restaurant card (a lerp to
                      // transparent black had turned it grey).
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(screenWidth * 0.05),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: screenWidth * 0.01,
                          offset: Offset(0, screenHeight * 0.0025),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          size: screenWidth * 0.035,
                          color: const Color(0xFF4CAF50),
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

                // Rating Badge
                Positioned(
                  bottom: screenHeight * 0.02,
                  right: screenWidth * 0.04,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.03,
                      vertical: screenHeight * 0.008,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(screenWidth * 0.05),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: screenWidth * 0.01,
                          offset: Offset(0, screenHeight * 0.0025),
                        ),
                      ],
                    ),
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
            
            // Supermarket Info
            Padding(
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
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(screenWidth * 0.02),
                          ),
                          child: Text(
                            l.shopOpen,
                            style: TextStyle(
                              color: const Color(0xFF4CAF50),
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
                  
                  // Delivery Info Row
                  Row(
                    children: [
                      _buildInfoItem(
                        Icons.delivery_dining_outlined,
                        // Platform flat rate — see supermarket_detail_screen.
                        CurrencyFormatter.formatPrice(kFlatDeliveryFee),
                        l.deliveryLabel,
                        screenWidth,
                        onCard,
                      ),
                      SizedBox(width: screenWidth * 0.06),
                      _buildInfoItem(
                        Icons.shopping_bag_outlined,
                        CurrencyFormatter.formatPrice(supermarket.minimumOrder),
                        l.minOrderLabel,
                        screenWidth,
                        onCard,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label,
      double screenWidth, Color valueColor) {
    return Row(
      children: [
        Icon(
          icon,
          size: screenWidth * 0.05,
          color: const Color(0xFF4CAF50),
        ),
        SizedBox(width: screenWidth * 0.02),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.035,
                color: valueColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
