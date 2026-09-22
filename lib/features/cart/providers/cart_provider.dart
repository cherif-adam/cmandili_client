import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/cart_item.dart';
import '../data/models/order_customization.dart';
import '../../../core/utils/delivery_fee.dart';

const _kCartKey = 'cmandili_cart_v1';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = list;
      }
    } catch (_) {
      // Corrupted data — start fresh
      state = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCartKey, jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void addItem(CartItem item) {
    // Keyed on cartLineKey (item + variant + option-group selections), not
    // just the base item id — two lines for the same item with different
    // picks must stay separate; identical picks still merge.
    final existingIndex = state.indexWhere(
      (cartItem) => cartItem.cartLineKey == item.cartLineKey,
    );

    if (existingIndex >= 0) {
      final updatedList = [...state];
      updatedList[existingIndex].quantity += item.quantity;
      state = updatedList;
    } else {
      state = [...state, item];
    }
    _persist();
  }

  void removeItem(String lineKey) {
    state = state.where((item) => item.cartLineKey != lineKey).toList();
    _persist();
  }

  void updateQuantity(String lineKey, int quantity) {
    if (quantity <= 0) {
      removeItem(lineKey);
      return;
    }

    state = state.map((item) {
      if (item.cartLineKey == lineKey) item.quantity = quantity;
      return item;
    }).toList();
    _persist();
  }

  void addCustomization(String itemId, OrderCustomization customization) {
    state = [
      for (final item in state)
        if (item.id == itemId)
          CartItem.restaurant(
            foodItem: item.foodItem,
            quantity: item.quantity,
            specialInstructions: item.specialInstructions,
            customization: customization,
          )
        else
          item,
    ];
    _persist();
  }

  void clearCart() {
    state = [];
    _persist();
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.totalPrice);
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.totalPrice);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

// Preview delivery fee shown in the cart screen before the customer picks a
// delivery address.
//
// Food carts: distance is unknown here, so this is the base fee (3.500 TND).
// Checkout recomputes it once the address is known, adding 0.500 TND/km beyond
// 3 km — so the preview is a floor the customer may see rise.
//
// Supermarket carts: flat rate, so the preview is the EXACT figure checkout
// will charge. Previewing the base fee here instead would advertise 3.500 and
// then bill 5.000 at checkout.
final cartDeliveryFeeProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  if (cart.isEmpty) return 0.0;
  // Mirrors how checkout classifies the order (a grocery line carries a
  // supermarketId); a cart never mixes verticals.
  final isSupermarket = cart.first.type == CartItemType.grocery;
  return calculateDeliveryFee(
    partnerFlatFee: isSupermarket ? kFlatDeliveryFee : kDeliveryBaseFee,
    isFlatRate: isSupermarket,
  );
});

final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final deliveryFee = ref.watch(cartDeliveryFeeProvider);
  return subtotal + deliveryFee;
});
