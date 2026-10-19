import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/data/models/restaurant.dart';
import '../../../restaurant/presentation/widgets/restaurant_card.dart';
import '../../providers/favorites_provider.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// "Favoris": the app bar, then either [_EmptyFavorites] or
/// [_FavoritesList]. UI only — the list comes from [favoritesProvider],
/// which loads and saves through FavoritesRepository.
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
          ? _EmptyFavorites(screenWidth: screenWidth, screenHeight: screenHeight)
          : _FavoritesList(
              restaurants: favoriteRestaurants,
              screenWidth: screenWidth,
            ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Heart icon + "no favourites yet".
class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.screenWidth, required this.screenHeight});

  final double screenWidth;
  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

/// One RestaurantCard per favourite.
class _FavoritesList extends StatelessWidget {
  const _FavoritesList({required this.restaurants, required this.screenWidth});

  final List<Restaurant> restaurants;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(screenWidth * 0.05),
      itemCount: restaurants.length,
      itemBuilder: (context, index) {
        return RestaurantCard(restaurant: restaurants[index]);
      },
    );
  }
}
