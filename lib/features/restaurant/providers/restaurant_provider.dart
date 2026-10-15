import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/nearby_provider.dart';
import '../data/restaurant_repository.dart';
import '../../home/data/models/restaurant.dart';
import '../../menu/data/models/item_variant.dart';
import '../../menu/data/models/food_item_option_group.dart';
import '../data/models/food_item.dart';

// Repository provider
final restaurantRepositoryProvider = Provider((ref) => RestaurantRepository());

// Live list of restaurants — updates automatically when a partner adds,
// edits, or removes one, no manual refresh needed.
final restaurantsProvider = StreamProvider<List<Restaurant>>((ref) {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.watchRestaurants();
});

/// The restaurants within [kShopRadiusKm] of the customer: what the home
/// screen lists. Refresh through [restaurantsProvider].
final nearbyRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  return keepNearby(
    ref.watch(customerPositionProvider),
    ref.watch(restaurantsProvider),
    (r) => (lat: r.latitude, lng: r.longitude),
  );
});

// Fetch food items for a specific restaurant from Supabase
final foodItemsProvider = FutureProvider.family<List<FoodItem>, String>((ref, restaurantId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getFoodItems(restaurantId);
});

// Variants for a single food item, fetched on-demand when the dish dialog opens.
// Superseded by foodItemCustomizationOptionsProvider at its one call site,
// but left here since nothing depends on removing it.
final foodItemVariantsProvider =
    FutureProvider.family<List<ItemVariant>, String>((ref, foodItemId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getFoodItemVariants(foodItemId);
});

// Variants + option groups for a single food item, fetched together so the
// customization sheet has one loading/error state instead of two.
final foodItemCustomizationOptionsProvider =
    FutureProvider.family<FoodItemCustomizationOptions, String>((ref, foodItemId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getFoodItemCustomizationOptions(foodItemId);
});
