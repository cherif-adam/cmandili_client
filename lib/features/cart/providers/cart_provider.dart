import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/cart_item.dart';
import '../data/models/order_customization.dart';
import '../../../core/utils/delivery_fee.dart';
import '../../restaurant/providers/restaurant_provider.dart';

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
    final existingIndex = state.indexWhere(
      (cartItem) => cartItem.id == item.id && cartItem.type == item.type,
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

  void removeItem(String itemId) {
    state = state.where((item) => item.id != itemId).toList();
    _persist();
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    state = state.map((item) {
      if (item.id == itemId) item.quantity = quantity;
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

// Preview delivery fee shown in the cart screen, before the customer picks a
// delivery address. Distance bonus can't be computed yet, so we just apply the
// 3 DT floor to the partner's flat fee. The final fee (with distance bonus)
// is recomputed in checkout once the address is known and stored on the order.
final cartDeliveryFeeProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  if (cart.isEmpty) return calculateDeliveryFee(partnerFlatFee: 0);
  final first = cart.first;
  final restaurantId = first.foodItem?.restaurantId;
  if (restaurantId == null) return calculateDeliveryFee(partnerFlatFee: 0);
  final restaurantsAsync = ref.watch(restaurantsProvider);
  return restaurantsAsync.when(
    data: (list) {
      final match = list.where((r) => r.id == restaurantId);
      final flat = match.isNotEmpty ? match.first.deliveryFee : 0.0;
      return calculateDeliveryFee(partnerFlatFee: flat);
    },
    loading: () => calculateDeliveryFee(partnerFlatFee: 0),
    error: (_, __) => calculateDeliveryFee(partnerFlatFee: 0),
  );
});

final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final deliveryFee = ref.watch(cartDeliveryFeeProvider);
  return subtotal + deliveryFee;
});
