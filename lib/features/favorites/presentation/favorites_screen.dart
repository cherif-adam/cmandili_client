import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../restaurant/presentation/widgets/restaurant_card.dart';
import '../../favorites/providers/favorites_provider.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    final favoriteRestaurants = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.favorites,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: screenWidth * 0.05,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      body: favoriteRestaurants.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: screenWidth * 0.2,
                    color: AppColors.textLight.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    AppLocalizations.of(context)!.noFavoritesYet,
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(screenWidth * 0.05),
              itemCount: favoriteRestaurants.length,
              itemBuilder: (context, index) {
                return RestaurantCard(restaurant: favoriteRestaurants[index]);
              },
            ),
    );
  }
}
