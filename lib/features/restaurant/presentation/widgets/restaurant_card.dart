import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../home/data/models/restaurant.dart';
import '../restaurant_detail_screen.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
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
          color: Colors.white,
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
            // Restaurant Image with Hero
            Hero(
              tag: 'restaurant_image_${restaurant.id}',
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(screenWidth * 0.06),
                      topRight: Radius.circular(screenWidth * 0.06),
                    ),
                    child: (restaurant.imageUrl.isNotEmpty && restaurant.imageUrl.startsWith('http'))
                      ? CachedNetworkImage(
                          imageUrl: restaurant.imageUrl,
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
                            child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: screenHeight * 0.25,
                          width: double.infinity,
                          color: AppColors.background,
                          child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                        ),
                  ),
                  
                  // Status Badge
                  Positioned(
                    top: screenHeight * 0.02,
                    left: screenWidth * 0.04,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03,
                        vertical: screenHeight * 0.008,
                      ),
                      decoration: BoxDecoration(
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
                            color: restaurant.isOpen ? AppColors.success : AppColors.error,
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            '${restaurant.deliveryTime} min',
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
                            '${restaurant.rating}',
                            style: TextStyle(
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
            
            // Restaurant Info
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        restaurant.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
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
                            'Open',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    restaurant.description,
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
                        CurrencyFormatter.formatPrice(restaurant.deliveryFee),
                        'Delivery',
                        screenWidth,
                      ),
                      SizedBox(width: screenWidth * 0.06),
                      _buildInfoItem(
                        Icons.shopping_bag_outlined,
                        CurrencyFormatter.formatPrice(restaurant.minimumOrder),
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
          color: AppColors.primary,
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
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
