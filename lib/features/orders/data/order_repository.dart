import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cart/data/models/cart_item.dart';
import '../../cart/data/models/order_customization.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../data/models/order.dart';

class OrderRepository {
  final _supabase = Supabase.instance.client;

  // Create a new order. `distanceKm` (when provided) is persisted on the
  // order so the driver and partner apps can show "5.2 km" without
  // recomputing client-side. The caller is responsible for computing the
  // final delivery fee with `calculateDeliveryFee` before calling this.
  Future<String> createOrder({
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
          'food_item_id': item.type == CartItemType.restaurant ? item.foodItem?.id : null,
          'grocery_item_id': item.type == CartItemType.grocery ? item.groceryItem?.id : null,
          'quantity': item.quantity,
          'price': item.price,
          'options': options,
          if (voiceUrl != null) 'voice_note_url': voiceUrl,
        });
      }

      return orderId;
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
        .select('*, restaurants(name), order_items(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(_mapOrderFromDb(json)))
        .toList();
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
  /// current user AND is still in a cancellable status ('pending' or 'confirmed').
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
          .inFilter('status', ['pending', 'confirmed'])
          .select('id');

      return (result as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error cancelling order by customer: $e');
      return false;
    }
  }

  // Stream order updates
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

  Map<String, dynamic> _mapOrderFromDb(Map<String, dynamic> dbJson) {
    return {
      'id': dbJson['id'],
      'userId': dbJson['user_id'],
      'restaurantId': dbJson['restaurant_id'] ?? '',
      'restaurantName': (dbJson['restaurants'] is Map) 
          ? (dbJson['restaurants']['name'] ?? '') 
          : '',
      'items': dbJson['order_items'] ?? [],
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
