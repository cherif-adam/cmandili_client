import 'package:supabase_flutter/supabase_flutter.dart';
import '../../home/data/models/restaurant.dart';
import '../../menu/data/models/item_variant.dart';
import '../../menu/data/models/food_item_option_group.dart';
import '../data/models/food_item.dart';

class RestaurantRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Restaurant>> getRestaurants() async {
    final response = await _supabase
        .from('restaurants')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Restaurant.fromJson(_mapFromDb(json)))
        .toList();
  }

  Future<List<FoodItem>> getFoodItems(String restaurantId) async {
    final response = await _supabase
        .from('food_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .order('category', ascending: true);

    return (response as List)
        .map((json) => FoodItem.fromJson(_mapFoodItemFromDb(json)))
        .toList();
  }

  /// Loads the list of named variants for a single food item, sorted by the
  /// partner's chosen order. Returns [] for items without variants — the
  /// caller falls back to the item's base price.
  Future<List<ItemVariant>> getFoodItemVariants(String foodItemId) async {
    try {
      final response = await _supabase
          .from('food_item_variants')
          .select()
          .eq('food_item_id', foodItemId)
          .eq('is_available', true)
          .order('sort_order', ascending: true);
      return (response as List).map((r) => ItemVariant.fromDb(r)).toList();
    } catch (e) {
      // Handle the case where the table doesn't exist or other db errors
      return [];
    }
  }

  /// Loads the reusable option groups (Sauce au choix, Suppléments, ...)
  /// linked to a food item, each with its available options, ordered by the
  /// *link's* sort_order (not the group's own restaurant-level default —
  /// the same group can be positioned differently across the different
  /// items it's linked to). Returns [] for items with none, or if the
  /// tables aren't live yet — same safety margin as [getFoodItemVariants].
  Future<List<FoodItemOptionGroup>> getFoodItemOptionGroups(String foodItemId) async {
    try {
      final response = await _supabase
          .from('food_item_option_group_links')
          .select('sort_order, food_item_option_groups(id, name, min_selections, '
              'max_selections, is_required, sort_order, '
              'food_item_options(id, name, price, is_available, sort_order))')
          .eq('food_item_id', foodItemId)
          .order('sort_order', ascending: true);
      return (response as List)
          .map((row) => FoodItemOptionGroup.fromDb(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Variants and option groups fetched together — the customization sheet
  /// always needs both at once, so one combined future beats reconciling two
  /// independent loading states. No latency cost: both queries run
  /// concurrently via [Future.wait].
  Future<FoodItemCustomizationOptions> getFoodItemCustomizationOptions(String foodItemId) async {
    final results = await Future.wait([
      getFoodItemVariants(foodItemId),
      getFoodItemOptionGroups(foodItemId),
    ]);
    return FoodItemCustomizationOptions(
      variants: results[0] as List<ItemVariant>,
      optionGroups: results[1] as List<FoodItemOptionGroup>,
    );
  }

  // Map database column names to model field names
  Map<String, dynamic> _mapFromDb(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'name': dbJson['name'],
      'description': dbJson['description'],
      'imageUrl': dbJson['image_url'],
      'rating': dbJson['rating'],
      'reviewCount': dbJson['review_count'],
      'deliveryTime': dbJson['delivery_time_min'] ?? 30,
      'deliveryFee': dbJson['delivery_fee'],
      'minimumOrder': dbJson['min_order'],
      'categories': dbJson['categories'] != null ? List<String>.from(dbJson['categories']) : <String>[],
      'isOpen': dbJson['is_open'],
      'latitude': dbJson['latitude'],
      'longitude': dbJson['longitude'],
      'openingTime': dbJson['opening_time'],
    };
  }

  Map<String, dynamic> _mapFoodItemFromDb(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'restaurantId': dbJson['restaurant_id'],
      'name': dbJson['name'],
      'description': dbJson['description'],
      'imageUrl': dbJson['image_url'],
      'price': dbJson['price'],
      'category': dbJson['category'],
      'isAvailable': dbJson['is_available'],
      'tags': [], // Can be added later
      'preparationTime': dbJson['preparation_time'],
      'isVegetarian': dbJson['is_vegetarian'],
      'isSpicy': dbJson['is_spicy'],
      'discountPrice': dbJson['discount_price'],
      'discountEndTime': dbJson['discount_end_time'],
      'discountQuantity': null,
    };
  }
}
