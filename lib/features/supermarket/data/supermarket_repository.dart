import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/supermarket.dart';
import '../data/models/grocery_item.dart';
import '../../menu/data/models/item_variant.dart';

class SupermarketRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Supermarket>> getSupermarkets() async {
    final response = await _supabase
        .from('supermarkets')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) => _mapFromDb(json)).toList();
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
  Supermarket _mapFromDb(Map<String, dynamic> dbJson) {
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
    };
  }
}
