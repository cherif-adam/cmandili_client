import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/data/models/restaurant.dart';
import '../../features/menu/data/models/food_item_option_group.dart';
import '../../features/menu/data/models/item_variant.dart';
import '../../features/restaurant/data/models/food_item.dart';
import '../../features/supermarket/data/models/grocery_item.dart';
import '../../features/supermarket/data/models/supermarket.dart';
import '../models/vendor.dart';

/// Every read of shops and their items, in one place.
///
/// Three families of tables, read exactly as before the merge:
///   - the generic `vendors` / `vendor_items` / `vendor_categories` tables,
///     which serve every category (adding flowers or pet supplies needs no
///     new code here);
///   - the historical `restaurants` / `food_items` views and their variant
///     and option-group tables;
///   - the historical `supermarkets` / `grocery_items` views and their
///     variants.
/// The views keep their own column names; the private mappers at the end of
/// each section are the thin adapter from those columns to the models.
class ShopRepository {
  final SupabaseClient _supabase;

  ShopRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  // ── Generic shops (vendors) ───────────────────────────────────────────────

  /// All active categories, ordered for display. Falls back to the built-in
  /// catalogue if the table cannot be read, so the home screen is never blank.
  Future<List<VendorCategory>> getCategories() async {
    try {
      final rows = await _supabase
          .from('vendor_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final list = (rows as List)
          .map((r) => VendorCategory.fromDb(r as Map<String, dynamic>))
          .toList();
      return list.isEmpty ? VendorCategory.fallback : list;
    } catch (_) {
      return VendorCategory.fallback;
    }
  }

  /// Shops in one category, newest first.
  Future<List<Vendor>> getVendors(String category) async {
    final rows = await _supabase
        .from('vendors')
        .select()
        .eq('category', category)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Vendor.fromDb(r as Map<String, dynamic>))
        .toList();
  }

  /// Live version of [getVendors] — pushes a new list the moment a shop is
  /// added, edited or removed.
  ///
  /// The category filter is applied client-side because Supabase's realtime
  /// `.stream()` only supports one `eq` on the primary key path; filtering
  /// server-side here would silently drop updates.
  Stream<List<Vendor>> watchVendors(String category) {
    return _supabase
        .from('vendors')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => Vendor.fromDb(r))
            .where((v) => v.category == category)
            .toList());
  }

  /// Every shop across all categories — used by search and the "near you"
  /// row, which are deliberately category-agnostic.
  Future<List<Vendor>> getAllVendors() async {
    final rows = await _supabase
        .from('vendors')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Vendor.fromDb(r as Map<String, dynamic>))
        .toList();
  }

  Future<Vendor?> getVendor(String id) async {
    final row =
        await _supabase.from('vendors').select().eq('id', id).maybeSingle();
    return row == null ? null : Vendor.fromDb(row);
  }

  /// Items belonging to one shop, available ones only, grouped by their
  /// in-shop section.
  Future<List<VendorItem>> getItems(String vendorId) async {
    final rows = await _supabase
        .from('vendor_items')
        .select()
        .eq('vendor_id', vendorId)
        .eq('is_available', true)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => VendorItem.fromDb(r as Map<String, dynamic>))
        .toList();
  }

  // ── Restaurants (restaurants / food_items views) ──────────────────────────

  Future<List<Restaurant>> getRestaurants() async {
    final response = await _supabase
        .from('restaurants')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Restaurant.fromJson(_restaurantFromDb(json)))
        .toList();
  }

  /// Live version of [getRestaurants] — pushes a new list the moment a
  /// restaurant is added, edited, or removed, instead of waiting for the
  /// screen to be reopened.
  Stream<List<Restaurant>> watchRestaurants() {
    return _supabase
        .from('restaurants')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) =>
            rows.map((json) => Restaurant.fromJson(_restaurantFromDb(json))).toList());
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
  Map<String, dynamic> _restaurantFromDb(Map<String, dynamic> dbJson) {
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
      'createdAt': dbJson['created_at'],
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
      'createdAt': dbJson['created_at'],
    };
  }

  // ── Supermarkets (supermarkets / grocery_items views) ─────────────────────

  Future<List<Supermarket>> getSupermarkets() async {
    final response = await _supabase
        .from('supermarkets')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) => _supermarketFromDb(json)).toList();
  }

  /// Live version of [getSupermarkets] — pushes a new list the moment a
  /// supermarket is added, edited, or removed, instead of waiting for the
  /// screen to be reopened.
  Stream<List<Supermarket>> watchSupermarkets() {
    return _supabase
        .from('supermarkets')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map((json) => _supermarketFromDb(json)).toList());
  }

  Future<List<GroceryItem>> getGroceryItems(String supermarketId) async {
    final response = await _supabase
        .from('grocery_items')
        .select()
        .eq('supermarket_id', supermarketId)
        .eq('is_available', true)
        .order('category', ascending: true);

    return (response as List)
        .map((json) => GroceryItem.fromJson(_mapGroceryItemFromDb(json)))
        .toList();
  }

  /// Loads variants for a single grocery item, ordered by sort_order. Empty
  /// list when no variants — caller falls back to base price.
  Future<List<ItemVariant>> getGroceryItemVariants(String groceryItemId) async {
    final response = await _supabase
        .from('grocery_item_variants')
        .select()
        .eq('grocery_item_id', groceryItemId)
        .eq('is_available', true)
        .order('sort_order', ascending: true);
    return (response as List).map((r) => ItemVariant.fromDb(r)).toList();
  }

  // Map database column names to Supermarket model
  Supermarket _supermarketFromDb(Map<String, dynamic> dbJson) {
    return Supermarket(
      id: dbJson['id'],
      name: dbJson['name'] ?? '',
      description: dbJson['description'] ?? '',
      imageUrl: dbJson['image_url'] ?? '',
      rating: (dbJson['rating'] ?? 0).toDouble(),
      reviewCount: dbJson['review_count'] ?? 0,
      deliveryTime: dbJson['delivery_time_min'] ?? 30,
      deliveryFee: (dbJson['delivery_fee'] ?? 0).toDouble(),
      minimumOrder: (dbJson['min_order'] ?? 0).toDouble(),
      isOpen: dbJson['is_open'] ?? true,
      latitude: (dbJson['latitude'] ?? 0).toDouble(),
      longitude: (dbJson['longitude'] ?? 0).toDouble(),
      openingTime: dbJson['opening_time'] as String?,
    );
  }

  Map<String, dynamic> _mapGroceryItemFromDb(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'supermarketId': dbJson['supermarket_id'],
      'name': dbJson['name'],
      'description': dbJson['description'],
      'imageUrl': dbJson['image_url'],
      'price': dbJson['price'],
      'category': dbJson['category'],
      'unit': dbJson['unit'],
      'isOrganic': dbJson['is_organic'],
      'isAvailable': dbJson['is_available'],
      'discountPrice': dbJson['discount_price'],
      'discountEndTime': dbJson['discount_end_time'],
      'discountQuantity': null,
      'createdAt': dbJson['created_at'],
    };
  }
}
