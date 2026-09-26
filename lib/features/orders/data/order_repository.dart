import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cart/data/models/cart_item.dart';
import '../../cart/data/models/order_customization.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../../../core/utils/platform_pricing.dart';
import '../../restaurant/data/models/food_item.dart';
import '../data/models/order.dart';

class OrderRepository {
  final _supabase = Supabase.instance.client;

  // Create a new order. `distanceKm` (when provided) is persisted on the
  // order so the driver and partner apps can show "5.2 km" without
  // recomputing client-side. The caller is responsible for computing the
  // final delivery fee with `calculateDeliveryFee` before calling this —
  // that's the STICKER price; if this turns out to be the customer's 5th/
  // 10th order, `apply_loyalty_at_checkout()` (BEFORE INSERT trigger)
  // overwrites delivery_fee/total server-side before the row is persisted.
  // The returned record reflects what was actually charged, not what was
  // requested — always use it (not the sticker price) for anything shown
  // to the user or passed to payment processing after this call.
  Future<
      ({
        String orderId,
        double deliveryFee,
        double total,
        String? loyaltyMilestoneType,
        double loyaltyDiscountAmount,
      })> createOrder({
    required List<CartItem> items,
    required DeliveryAddress deliveryAddress,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required OrderType orderType,
    String? restaurantId,
    String? supermarketId,
    String? notes,
    String paymentMethod = 'cash',
    double? distanceKm,
    DateTime? estimatedDeliveryTime,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      // Insert order in 'pending' — payment is confirmed synchronously after this
      final orderResponse = await _supabase.from('orders').insert({
        'user_id': userId,
        'restaurant_id': restaurantId,
        'supermarket_id': supermarketId,
        'status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': paymentMethod,
        'notes': notes,
        'delivery_address': deliveryAddress.toJson(),
        'order_type': orderType.toString().split('.').last,
        if (estimatedDeliveryTime != null)
          'estimated_delivery_time': estimatedDeliveryTime.toIso8601String(),
      }).select().single();

      final orderId = orderResponse['id'] as String;

      // Insert order items. If a customization holds a local voice clip, upload
      // it to the public `voice-messages` bucket and store the URL on
      // `order_items.voice_note_url` so the partner can stream it without a
      // signed-URL roundtrip.
      for (final item in items) {
        final customization = item.customization;
        String? voiceUrl;
        OrderCustomization? finalCustomization = customization;

        if (customization != null && customization.type == CustomizationType.voice) {
          if (customization.content.isNotEmpty && !customization.content.startsWith('http')) {
            voiceUrl = await _uploadVoiceClip(orderId, customization.content);
            if (voiceUrl != null) {
              finalCustomization = customization.copyWith(content: voiceUrl);
            }
          } else if (customization.content.startsWith('http')) {
            voiceUrl = customization.content;
          }
        }

        // Build the options JSONB blob: voice/text customization, the
        // selected variant, and any selected option-group add-ons (so the
        // partner can see "Chocolate cake — 8DT" / "Harissa, Gruyère" on the
        // order detail screen, even though it's also baked into `price`).
        final options = <String, dynamic>{};
        if (finalCustomization != null) {
          options.addAll(finalCustomization.toJson());
        }
        if (item.variant != null) {
          options['variant'] = item.variant!.toJson();
        }
        if (item.selectedOptionGroups.isNotEmpty) {
          options['optionGroups'] =
              item.selectedOptionGroups.map((g) => g.toJson()).toList();
        }

        await _supabase.from('order_items').insert({
          'order_id': orderId,
          // One nullable FK per vertical; exactly one is set per line. A
          // generic-vendor line (flowers, pets, gifts, bakery, electronics)
          // uses the third column — without it the line would save with every
          // product reference null and the partner could not tell what was
          // ordered.
          'food_item_id': item.type == CartItemType.restaurant ? item.foodItem?.id : null,
          'grocery_item_id': item.type == CartItemType.grocery ? item.groceryItem?.id : null,
          'vendor_item_id': item.type == CartItemType.vendor ? item.vendorItem?.id : null,
          'quantity': item.quantity,
          'price': item.price,
          'options': options,
          if (voiceUrl != null) 'voice_note_url': voiceUrl,
        });
      }

      return (
        orderId: orderId,
        deliveryFee: (orderResponse['delivery_fee'] as num).toDouble(),
        total: (orderResponse['total'] as num).toDouble(),
        loyaltyMilestoneType: orderResponse['loyalty_milestone_type'] as String?,
        loyaltyDiscountAmount:
            (orderResponse['loyalty_discount_amount'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  Future<List<Order>> getUserOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('orders')
        // `restaurants!orders_restaurant_id_fkey` rather than plain
        // `restaurants`. Since restaurants became a view over the generic
        // `vendors` table, PostgREST sees TWO paths from orders to it —
        // orders.restaurant_id and orders.supermarket_id both land there —
        // and refuses to guess, failing the whole order history with
        // PGRST201. Naming the constraint picks the restaurant leg.
        // Join each line's product row so the history/tracking screens can
        // show "2x Pizza Margherita" instead of a blank name. `food_items`
        // and `grocery_items` are now views over `vendors`, so PostgREST
        // can't resolve an embed through them — point the embed at the
        // underlying tables (same aliases the partner app uses) and keep
        // the view's name as the alias so the mapping below is unchanged.
        .select('*, restaurants!orders_restaurant_id_fkey(name), '
            'order_items(*, food_items:food_items_legacy(*), '
            'grocery_items:grocery_items_legacy(*), vendor_items(*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(_mapOrderFromDb(json)))
        .toList();
  }

  /// The customer's newest order that is not yet delivered or cancelled, or
  /// null. Deliberately a bare `select('*')` with no embeds: the history
  /// query's joins can fail on schema drift, and this call is the only way
  /// back into tracking, so it must not share that failure mode.
  Future<Order?> getActiveOrder() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('orders')
        .select('*')
        .eq('user_id', userId)
        .not('status', 'in', '(delivered,cancelled)')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Order.fromJson(_mapOrderFromDb(row));
  }

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
            // Same PGRST201 ambiguity as above: food_items reaches
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

  // Same shape as RestaurantRepository._mapFoodItemFromDb — duplicated
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

  /// Whether the customer has already rated this order. Used to gate the
  /// post-delivery rating prompt so it never reappears once submitted (the
  /// DB's own UNIQUE(order_id) + write-once RLS policy are the real
  /// enforcement — this is just what lets the UI decide whether to ask).
  Future<bool> hasRating(String orderId) async {
    final row = await _supabase
        .from('order_ratings')
        .select('id')
        .eq('order_id', orderId)
        .maybeSingle();
    return row != null;
  }

  /// Records a 1-5 star rating (+ optional comment) for a delivered food
  /// order. The DB trigger recomputes restaurants.rating/review_count from
  /// the full order_ratings set right after this insert — no client-side
  /// average to keep in sync. Returns false (instead of throwing) on any
  /// failure — RLS rejecting a stale/ineligible order, or a duplicate
  /// insert racing another device — since the caller only needs to know
  /// whether to show a confirmation or a generic retry message.
  Future<bool> submitRating({
    required String orderId,
    required String restaurantId,
    required int rating,
    String? comment,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      await _supabase.from('order_ratings').insert({
        'order_id': orderId,
        'user_id': userId,
        'restaurant_id': restaurantId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _supabase.from('orders').update({
        'status': status.toString().split('.').last,
      }).eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  /// Sets order status to 'confirmed' after successful payment.
  Future<bool> confirmOrder(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': 'confirmed'})
          .eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error confirming order: $e');
      return false;
    }
  }

  /// Cancel an order that failed payment (sets status to 'cancelled').
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  /// Customer-initiated cancellation. Only succeeds if the order belongs to the
  /// current user AND the goods have not been picked up yet.
  ///
  /// 'preparing' and 'ready' are cancellable too: an order the shop marked
  /// ready but that no driver ever collected used to trap the customer — the
  /// button refused it, and the only ways out were the partner app, the driver
  /// app or an admin. The cut-off is pickup, not readiness, because that is
  /// the point where a driver is actually carrying the food.
  ///
  /// Returns true if a row was actually updated (i.e. cancellation was applied).
  Future<bool> cancelOrderByCustomer(String orderId, String reason) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase
          .from('orders')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason,
            'cancelled_by': 'customer',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'confirmed', 'preparing', 'ready'])
          .select('id');

      return (result as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error cancelling order by customer: $e');
      return false;
    }
  }

  // Stream order updates
  /// Live version of [getActiveOrder]: emits the newest undelivered,
  /// uncancelled order (or null) every time any of the customer's orders
  /// changes, so a restaurant/driver status update shows up immediately.
  Stream<Order?> streamActiveOrder() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          Map<String, dynamic>? newest;
          for (final row in rows) {
            final status = row['status'];
            if (status == 'delivered' || status == 'cancelled') continue;
            if (newest == null ||
                '${row['created_at']}'.compareTo('${newest['created_at']}') > 0) {
              newest = row;
            }
          }
          return newest == null ? null : Order.fromJson(_mapOrderFromDb(newest));
        });
  }

  Stream<Order> streamOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((event) {
          if (event.isEmpty) {
            throw Exception('Order not found');
          }
          return Order.fromJson(_mapOrderFromDb(event.first));
        });
  }

  /// Uploads a local AAC voice clip to the public `voice-messages` bucket and
  /// returns its public URL. Returns null on failure (network, missing file,
  /// permission) so the order still succeeds without the voice note rather
  /// than blocking checkout.
  Future<String?> _uploadVoiceClip(String orderId, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ext = localPath.split('.').last.toLowerCase();
      final remotePath = '$orderId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('voice-messages').upload(
            remotePath,
            file,
            fileOptions: const FileOptions(contentType: 'audio/aac', upsert: true),
          );
      return _supabase.storage.from('voice-messages').getPublicUrl(remotePath);
    } catch (e) {
      debugPrint('Voice clip upload failed: $e');
      return null;
    }
  }

  /// Turn the joined `order_items` rows into the JSON shape
  /// [CartItem.fromJson] expects. The raw DB rows are snake_case and carry
  /// no product data of their own, so feeding them straight to CartItem
  /// threw "type 'Null' is not a subtype of type 'Map<String, dynamic>'"
  /// and failed the whole order history.
  ///
  /// `order_items.price` is the CLIENT price — it was written from
  /// [CartItem.price], which already includes the platform markup. Since
  /// that getter re-applies the markup when the line is read back, the
  /// stored price is divided back down to the base here; otherwise a past
  /// order would display 10% above what the customer actually paid.
  List<Map<String, dynamic>> _parseOrderItems(dynamic rawItems) {
    if (rawItems is! List) return [];
    final result = <Map<String, dynamic>>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final quantity = (row['quantity'] as num?)?.toInt() ?? 1;
      final clientPrice = (row['price'] as num?)?.toDouble() ?? 0.0;
      final basePrice = removePlatformMarkup(clientPrice);

      // `options` holds the variant and option-group picks made at
      // checkout. Their own prices are baked into `price` already, so they
      // are deliberately NOT replayed into the line — doing so would add
      // the add-on prices a second time. Only the names are kept, by
      // rebuilding the item name below.
      final options = row['options'];
      final optionsMap = options is Map
          ? Map<String, dynamic>.from(options)
          : const <String, dynamic>{};
      final variantName = (optionsMap['variant'] is Map)
          ? (optionsMap['variant'] as Map)['name']?.toString()
          : null;

      String nameWithVariant(String base) =>
          variantName == null || variantName.isEmpty
              ? base
              : '$base — $variantName';

      final foodData = row['food_items'];
      if (foodData is Map) {
        result.add({
          'type': 'restaurant',
          'quantity': quantity,
          'foodItem': {
            'id': foodData['id'] ?? row['food_item_id'] ?? '',
            'restaurantId': foodData['restaurant_id'] ?? '',
            'name': nameWithVariant(foodData['name']?.toString() ?? 'Item'),
            'description': foodData['description'] ?? '',
            'imageUrl': foodData['image_url'] ?? '',
            'price': basePrice, // order-time price, not today's menu price
            'category': foodData['category'] ?? '',
            'isAvailable': foodData['is_available'] ?? true,
            'tags': [],
            'preparationTime': foodData['preparation_time'] ?? 15,
            'isVegetarian': foodData['is_vegetarian'] ?? false,
            'isSpicy': foodData['is_spicy'] ?? false,
          },
        });
        continue;
      }

      final groceryData = row['grocery_items'];
      if (groceryData is Map) {
        result.add({
          'type': 'grocery',
          'quantity': quantity,
          'groceryItem': {
            'id': groceryData['id'] ?? row['grocery_item_id'] ?? '',
            'supermarketId': groceryData['supermarket_id'] ?? '',
            'name': nameWithVariant(groceryData['name']?.toString() ?? 'Item'),
            'description': groceryData['description'] ?? '',
            'imageUrl': groceryData['image_url'] ?? '',
            'price': basePrice,
            'category': groceryData['category'] ?? 'vegetables',
            'unit': groceryData['unit'] ?? 'piece',
            'isOrganic': groceryData['is_organic'] ?? false,
            'isAvailable': groceryData['is_available'] ?? true,
          },
        });
        continue;
      }

      // Generic vendor line (flowers, pets, gifts, bakery, electronics).
      // VendorItem is built by `VendorItem.fromDb`, so this one stays
      // snake_case unlike the two branches above.
      final vendorData = row['vendor_items'];
      if (vendorData is Map) {
        result.add({
          'type': 'vendor',
          'quantity': quantity,
          'vendorItem': {
            'id': vendorData['id'] ?? row['vendor_item_id'] ?? '',
            'vendor_id': vendorData['vendor_id'] ?? '',
            'name': nameWithVariant(vendorData['name']?.toString() ?? 'Item'),
            'description': vendorData['description'] ?? '',
            'image_url': vendorData['image_url'] ?? '',
            'price': basePrice,
            'category': vendorData['category'],
            'unit': vendorData['unit'],
            'is_organic': vendorData['is_organic'] ?? false,
            'is_available': vendorData['is_available'] ?? true,
          },
        });
        continue;
      }

      // The product row is gone (deleted item) or this is a courier/facture
      // line with no product at all. Still render something priced
      // correctly rather than dropping the line from the order.
      result.add({
        'type': 'restaurant',
        'quantity': quantity,
        'foodItem': {
          'id': row['food_item_id'] ?? '',
          'restaurantId': '',
          'name': nameWithVariant(row['name']?.toString() ?? 'Item'),
          'description': '',
          'imageUrl': '',
          'price': basePrice,
          'category': '',
          'isAvailable': true,
          'tags': [],
          'preparationTime': 15,
          'isVegetarian': false,
          'isSpicy': false,
        },
      });
    }

    return result;
  }

  Map<String, dynamic> _mapOrderFromDb(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'userId': dbJson['user_id'],
      'restaurantId': dbJson['restaurant_id'] ?? '',
      'restaurantName': (dbJson['restaurants'] is Map) 
          ? (dbJson['restaurants']['name'] ?? '') 
          : '',
      'items': _parseOrderItems(dbJson['order_items']),
      'deliveryAddress': dbJson['delivery_address'] ?? {},
      'subtotal': dbJson['subtotal'],
      'deliveryFee': dbJson['delivery_fee'],
      'total': dbJson['total'],
      'status': dbJson['status'],
      'createdAt': dbJson['created_at'],
      'estimatedDeliveryTime': dbJson['estimated_delivery_time'],
      'driverId': dbJson['driver_id'],
      'driverName': null,
      'driverPhone': null,
      'driverLatitude': null,
      'driverLongitude': null,
      'paymentMethod': dbJson['payment_method'],
      'notes': dbJson['notes'],
      'type': dbJson['order_type'],
      'pickupAddress': dbJson['pickup_address'],
      'recipientName': dbJson['recipient_name'],
      'recipientPhone': dbJson['recipient_phone'],
      'packageDescription': dbJson['package_description'],
      'isRecipientAccepted': false,
      'billType': dbJson['bill_type'],
      'billReference': dbJson['bill_reference'],
      'billAmount': dbJson['bill_amount'],
      'billPhotoUrl': dbJson['bill_photo_url'],
      'billReceiptUrl': dbJson['bill_receipt_url'],
      'senderPhone': dbJson['sender_phone'],
      'loyaltyMilestoneType': dbJson['loyalty_milestone_type'],
      'loyaltyDiscountAmount': dbJson['loyalty_discount_amount'],
    };
  }

  /// Customer's lifetime delivered-order count for the loyalty program
  /// (unified across food/courier/facture). Returns 0 if the customer has
  /// no qualifying delivered order yet (no row exists).
  Future<int> getLoyaltyDeliveredCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final row = await _supabase
          .from('loyalty_customer_progress')
          .select('delivered_count')
          .eq('customer_id', userId)
          .maybeSingle();
      return (row?['delivered_count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error fetching loyalty progress: $e');
      return 0;
    }
  }

  Future<List<Order>> getBillOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('orders')
        .select('*')
        .eq('user_id', userId)
        .eq('order_type', 'facture')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(_mapOrderFromDb(json)))
        .toList();
  }
}
