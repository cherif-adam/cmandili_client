import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cart/data/models/cart_item.dart';
import '../../cart/data/models/order_customization.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../data/models/order.dart';

/// Creates an order and its lines (with the voice-note upload).
class OrderPlacementRepository {
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

      // From here on the order row exists. If one of its lines cannot be
      // saved, cancel it before giving up: on 30/10 a line the database
      // refused left three orders 'pending' with no item, waiting in the
      // partner's queue. The caller releases a committed promo; the
      // cancellation trigger frees the loyalty slot.
      try {
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

          // The customer's typed note. The partner app shows a text note from
          // order_items.special_instructions and nothing else, but this only
          // ever went into `options` (below) -- so "Instructions spéciales" was
          // saved and never seen by the shop. Written to both now: the column
          // for the partner, `options` unchanged for anything already reading it.
          final typedNote = (finalCustomization != null &&
                  finalCustomization.type == CustomizationType.text)
              ? finalCustomization.content.trim()
              : (item.specialInstructions ?? '').trim();

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
            if (typedNote.isNotEmpty) 'special_instructions': typedNote,
            if (voiceUrl != null) 'voice_note_url': voiceUrl,
          });
        }
      } catch (_) {
        await _cancelEmptyOrder(orderId);
        rethrow;
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

  /// Cancels an order whose lines could not all be saved, so it does not
  /// sit 'pending' and empty in the partner's queue. Best effort: the error
  /// the caller needs is the one that stopped the order, not this one.
  Future<void> _cancelEmptyOrder(String orderId) async {
    try {
      await _supabase.from('orders').update({
        'status': 'cancelled',
        'cancelled_by': 'system',
        'cancellation_reason': 'Articles non enregistrés',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);
    } catch (e) {
      debugPrint('createOrder: could not cancel the empty order $orderId: $e');
    }
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
}
