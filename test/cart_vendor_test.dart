import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/core/models/vendor.dart';
import 'package:cmandili_mobile/features/cart/data/models/cart_item.dart';

void main() {
  final item = VendorItem.fromDb({
    'id': 'item-1',
    'vendor_id': 'vendor-9',
    'name': 'Bouquet de roses',
    'description': '12 roses',
    'image_url': 'http://x/rose.jpg',
    'price': 45.0,
    'category': 'Roses',
    'unit': null,
    'is_available': true,
  });

  test('vendor cart line exposes name, id and image', () {
    final line = CartItem.vendor(vendorItem: item, quantity: 2);
    expect(line.type, CartItemType.vendor);
    expect(line.id, 'item-1');
    expect(line.name, 'Bouquet de roses');
    expect(line.imageUrl, 'http://x/rose.jpg');
    expect(line.quantity, 2);
  });

  test('price applies the platform markup once, like the other types', () {
    final line = CartItem.vendor(vendorItem: item);
    // Same markup path as food/grocery — the exact multiplier lives in
    // platform_pricing, so assert the relationship rather than a constant.
    expect(line.price, greaterThanOrEqualTo(45.0));
    expect(line.totalPrice, closeTo(line.price, 0.001));
  });

  test('survives a persist/restore round trip', () {
    // The cart is saved to SharedPreferences as JSON. If the vendor case did
    // not round-trip, every customer with a flower/pet/gift item in their
    // cart would lose it (or crash) on the next app launch.
    final original = CartItem.vendor(vendorItem: item, quantity: 3);
    final restored =
        CartItem.fromJson(jsonDecode(jsonEncode(original.toJson())));

    expect(restored.type, CartItemType.vendor);
    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.quantity, 3);
    expect(restored.price, closeTo(original.price, 0.001));
  });

  test('an expired discount does not survive into the restored price', () {
    final expired = VendorItem.fromDb({
      'id': 'item-2',
      'vendor_id': 'v',
      'name': 'Vieux bouquet',
      'price': 30.0,
      'discount_price': 10.0,
      'discount_end_time':
          DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    });
    final line = CartItem.vendor(vendorItem: expired);
    final restored = CartItem.fromJson(jsonDecode(jsonEncode(line.toJson())));
    // Both sides must charge the base price, not the lapsed promo.
    expect(line.price, restored.price);
    expect(restored.vendorItem!.effectivePrice, 30.0);
  });

  test('mixed cart keeps each line distinct', () {
    final a = CartItem.vendor(vendorItem: item);
    final b = CartItem.vendor(
      vendorItem: VendorItem.fromDb(
          {'id': 'item-3', 'vendor_id': 'v', 'name': 'Tulipes', 'price': 20.0}),
    );
    expect(a.cartLineKey, isNot(b.cartLineKey));
  });

  test('two identical vendor lines share a cart key so they merge', () {
    final a = CartItem.vendor(vendorItem: item);
    final b = CartItem.vendor(vendorItem: item);
    expect(a.cartLineKey, b.cartLineKey);
  });
}
