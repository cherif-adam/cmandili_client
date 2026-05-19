import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/restaurant_repository.dart';
import '../../home/data/models/restaurant.dart';
import '../../menu/data/models/item_variant.dart';
import '../data/models/food_item.dart';

// Repository provider
final restaurantRepositoryProvider = Provider((ref) => RestaurantRepository());

// Fetch all restaurants from Supabase
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getRestaurants();
});

// Fetch food items for a specific restaurant from Supabase
final foodItemsProvider = FutureProvider.family<List<FoodItem>, String>((ref, restaurantId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getFoodItems(restaurantId);
});

// Variants for a single food item, fetched on-demand when the dish dialog opens.
final foodItemVariantsProvider =
    FutureProvider.family<List<ItemVariant>, String>((ref, foodItemId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getFoodItemVariants(foodItemId);
});
