import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cart/data/models/cart_item.dart';
import '../../restaurant/data/models/food_item.dart';

/// "Reorder" on order history: today's items for a past order.
class ReorderRepository {
  final _supabase = Supabase.instance.client;

  /// Fresh, current-price/current-availability items for a past order — used
  /// by "Reorder" on order history. Deliberately does NOT replay the
  /// original order's variant/option-group picks (order_items.options) or
  /// its snapshot price; it re-adds the same base items the way the
  /// customer would by picking them again from today's menu. Food orders
  /// only — the client app has no supermarket reorder entry point (yet).
  /// Returns the resolvable items plus how many were skipped (item deleted,
  /// no longer available, or its restaurant is now closed) so the caller can
  /// tell the customer rather than silently reordering less than expected.
  Future<({List<CartItem> items, int skippedCount})> getReorderItems(
      String orderId) async {
    final itemRows = await _supabase
        .from('order_items')
        .select('food_item_id, quantity')
        .eq('order_id', orderId);

    final items = <CartItem>[];
    var skipped = 0;

    for (final row in (itemRows as List).cast<Map<String, dynamic>>()) {
      final foodItemId = row['food_item_id'] as String?;
      final quantity = (row['quantity'] as num?)?.toInt() ?? 1;
      if (foodItemId == null) {
        skipped++; // courier/facture orders, or a grocery line — not reorderable here
        continue;
      }
      try {
        final itemRow = await _supabase
            .from('food_items')
            // Same PGRST201 ambiguity as in OrderRepository.getUserOrders:
            // food_items reaches
            // restaurants through its own restaurant_id.
            .select('*, restaurants!food_items_restaurant_id_fkey(is_open)')
            .eq('id', foodItemId)
            .maybeSingle();
        final isAvailable = itemRow?['is_available'] as bool? ?? false;
        final restaurantOpen =
            (itemRow?['restaurants'] as Map?)?['is_open'] as bool? ?? true;
        if (itemRow == null || !isAvailable || !restaurantOpen) {
          skipped++;
          continue;
        }
        items.add(CartItem.restaurant(
          foodItem: FoodItem.fromJson(_mapFoodItemFromDbForReorder(itemRow)),
          quantity: quantity,
        ));
      } catch (_) {
        skipped++;
      }
    }

    return (items: items, skippedCount: skipped);
  }

  // Same shape as ShopRepository._mapFoodItemFromDb — duplicated
  // rather than shared, matching this codebase's existing convention of each
  // repository owning its own DB-row-to-model mapping.
  Map<String, dynamic> _mapFoodItemFromDbForReorder(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'restaurantId': dbJson['restaurant_id'],
      'name': dbJson['name'],
      'description': dbJson['description'],
      'imageUrl': dbJson['image_url'],
      'price': dbJson['price'],
      'category': dbJson['category'],
      'isAvailable': dbJson['is_available'],
      'tags': [],
      'preparationTime': dbJson['preparation_time'],
      'isVegetarian': dbJson['is_vegetarian'],
      'isSpicy': dbJson['is_spicy'],
      'discountPrice': dbJson['discount_price'],
      'discountEndTime': dbJson['discount_end_time'],
      'discountQuantity': null,
    };
  }
}
