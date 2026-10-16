import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/data/models/restaurant.dart';
import 'restaurant_stats_card.dart';

/// Under the photo of a restaurant's page: its name, description and the
/// [RestaurantStatsCard]. Slightly overlaps the photo (rounded top).
class RestaurantInfoHeader extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantInfoHeader({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      transform: Matrix4.translationValues(0, -20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      restaurant.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          RestaurantStatsCard(restaurant: restaurant),
        ],
      ),
    );
  }
}
