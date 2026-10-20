import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/nearby_provider.dart';
import '../../../core/providers/vendor_provider.dart';
import '../../home/data/models/restaurant.dart';
import '../../menu/data/models/food_item_option_group.dart';
import '../data/models/food_item.dart';

// Live list of restaurants — updates automatically when a partner adds,
// edits, or removes one, no manual refresh needed.
final restaurantsProvider = StreamProvider<List<Restaurant>>((ref) {
  final repository = ref.watch(shopRepositoryProvider);
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
  final repository = ref.watch(shopRepositoryProvider);
  return repository.getFoodItems(restaurantId);
});

// Variants + option groups for a single food item, fetched together so the
// customization sheet has one loading/error state instead of two.
final foodItemCustomizationOptionsProvider =
    FutureProvider.family<FoodItemCustomizationOptions, String>((ref, foodItemId) async {
  final repository = ref.watch(shopRepositoryProvider);
  return repository.getFoodItemCustomizationOptions(foodItemId);
});
