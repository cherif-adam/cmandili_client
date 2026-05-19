import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supermarketsAsync = ref.watch(supermarketsProvider);

    return supermarketsAsync.when(
      data: (supermarkets) => SliverPadding(
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.05,
          screenHeight * 0.02,
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
    );
  }
}

class _SupermarketCard extends StatelessWidget {
  final Supermarket supermarket;
  final double screenWidth;
  final double screenHeight;

  const _SupermarketCard({
    required this.supermarket,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                      color: AppColors.background,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.background,
                      child: const Icon(Icons.store),
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
                      color: Color.lerp(Colors.white, Colors.transparent, 0.1)!, // Replaced withOpacity
                      borderRadius: BorderRadius.circular(screenWidth * 0.05),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                          '${supermarket.deliveryTime} min',
                          style: TextStyle(
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
                          color: Colors.black.withOpacity(0.1),
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
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth * 0.03,
                          ),
                        ),
                        Text(
                          ' (${supermarket.reviewCount})',
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.8),
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
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
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
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(screenWidth * 0.02),
                          ),
                          child: Text(
                            'Open',
                            style: TextStyle(
                              color: const Color(0xFF4CAF50),
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                        CurrencyFormatter.formatPrice(supermarket.deliveryFee),
                        'Delivery',
                        screenWidth,
                      ),
                      SizedBox(width: screenWidth * 0.06),
                      _buildInfoItem(
                        Icons.shopping_bag_outlined,
                        CurrencyFormatter.formatPrice(supermarket.minimumOrder),
                        'Min. Order',
                        screenWidth,
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

  Widget _buildInfoItem(IconData icon, String value, String label, double screenWidth) {
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
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
