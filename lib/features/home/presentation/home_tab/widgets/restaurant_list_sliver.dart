import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/providers/nearby_provider.dart';
import '../../../../restaurant/presentation/widgets/restaurant_card.dart';
import '../../../../restaurant/providers/restaurant_provider.dart';
import '../../../data/models/restaurant.dart';

/// The restaurant cards of the home tab, filtered by the selected cuisine
/// and the search text. Also shows the loading, error and "nothing within
/// 15 km" states.
///
/// Returns a sliver, so it goes in a [CustomScrollView]'s slivers.
class RestaurantListSliver extends ConsumerWidget {
  /// Already limited to the restaurants near the customer.
  final AsyncValue<List<Restaurant>> restaurants;
  final String selectedCategory;
  final String searchQuery;
  final double screenWidth;
  final double screenHeight;

  const RestaurantListSliver({
    super.key,
    required this.restaurants,
    required this.selectedCategory,
    required this.searchQuery,
    required this.screenWidth,
    required this.screenHeight,
  });

  List<Restaurant> _filter(List<Restaurant> restaurantList) {
    var filtered = restaurantList;
    // Filter by category
    if (selectedCategory != 'All') {
      filtered = filtered
          .where((r) => r.categories
              .any((c) => c.toLowerCase() == selectedCategory.toLowerCase()))
          .toList();
    }
    // Filter by search query (name, description, or category — so typing
    // "pâtisseries" finds tagged venues too)
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.name.toLowerCase().contains(searchQuery) ||
              r.description.toLowerCase().contains(searchQuery) ||
              r.categories.any((c) => c.toLowerCase().contains(searchQuery)))
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.05,
        0,
        screenWidth * 0.05,
        screenHeight * 0.12, // Bottom padding for floating nav
      ),
      sliver: restaurants.when(
        data: (restaurantList) {
          final filtered = _filter(restaurantList);
          if (filtered.isEmpty) return _empty(context);
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => RestaurantCard(restaurant: filtered[index]),
              childCount: filtered.length,
            ),
          );
        },
        loading: () => SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(screenHeight * 0.05),
              child: const CircularProgressIndicator(),
            ),
          ),
        ),
        error: (error, stack) => _error(context, ref),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(screenHeight * 0.05),
          child: Column(
            children: [
              Icon(Icons.search_off, size: screenWidth * 0.12, color: Colors.grey[400]),
              SizedBox(height: screenHeight * 0.02),
              Text(
                // Nothing typed or picked: the list is empty
                // because of the distance, so say that.
                searchQuery.isEmpty && selectedCategory == 'All'
                    ? AppLocalizations.of(context)!
                        .noRestaurantsNearby(kShopRadiusKm.round())
                    : AppLocalizations.of(context)!.noRestaurantsFound,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(screenHeight * 0.05),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.errorLoadingRestaurants,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenHeight * 0.02),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(restaurantsProvider),
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
