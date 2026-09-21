import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/core/models/vendor.dart';

void main() {
  Map<String, dynamic> itemRow({
    double price = 10,
    double? discountPrice,
    String? discountEnd,
  }) =>
      {
        'id': 'i1',
        'vendor_id': 'v1',
        'name': 'Bouquet de roses',
        'description': '12 roses rouges',
        'image_url': '',
        'price': price,
        'category': 'Roses',
        'is_available': true,
        'discount_price': discountPrice,
        'discount_end_time': discountEnd,
      };

  group('VendorItem.effectivePrice', () {
    test('no discount → base price', () {
      final item = VendorItem.fromDb(itemRow());
      expect(item.effectivePrice, 10);
      expect(item.hasActiveDiscount, isFalse);
    });

    test('discount with no end time → discounted price', () {
      final item = VendorItem.fromDb(itemRow(discountPrice: 7));
      expect(item.effectivePrice, 7);
      expect(item.hasActiveDiscount, isTrue);
    });

    test('discount still running → discounted price', () {
      final future = DateTime.now().add(const Duration(hours: 2));
      final item = VendorItem.fromDb(
        itemRow(discountPrice: 7, discountEnd: future.toIso8601String()),
      );
      expect(item.effectivePrice, 7);
    });

    test('EXPIRED discount falls back to base price', () {
      // The bug this guards: an expired promotion leaking into the cart
      // total and the order the customer is charged for.
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      final item = VendorItem.fromDb(
        itemRow(discountPrice: 7, discountEnd: past.toIso8601String()),
      );
      expect(item.effectivePrice, 10);
      expect(item.hasActiveDiscount, isFalse);
    });
  });

  group('Vendor.fromDb', () {
    test('reads a full row', () {
      final v = Vendor.fromDb({
        'id': 'v1',
        'category': 'flowers',
        'name': 'Fleurs de Sousse',
        'description': 'Bouquets',
        'image_url': 'http://x/y.jpg',
        'rating': 4.5,
        'review_count': 22,
        'delivery_time_min': 25,
        'delivery_fee': 2.5,
        'min_order': 5,
        'categories': ['roses', 'mariage'],
        'is_open': true,
        'latitude': 35.82,
        'longitude': 10.63,
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(v.category, 'flowers');
      expect(v.rating, 4.5);
      expect(v.categories, ['roses', 'mariage']);
      expect(v.isNew, isTrue); // created just now
    });

    test('tolerates a sparse row without throwing', () {
      // Rows for a brand-new category are often half-filled by the partner;
      // a null must never crash the list screen.
      final v = Vendor.fromDb({'id': 'v2', 'category': 'pets', 'name': 'Zoo'});
      expect(v.name, 'Zoo');
      expect(v.rating, 0);
      expect(v.deliveryTime, 30);
      expect(v.categories, isEmpty);
      expect(v.isOpen, isTrue);
      expect(v.isNew, isFalse); // no created_at
    });

    test('integer rating from Postgres numeric is accepted', () {
      // Postgres returns numeric as int when the value is whole, which a
      // plain `as double` cast would throw on.
      final v = Vendor.fromDb(
          {'id': 'v3', 'category': 'gifts', 'name': 'G', 'rating': 4});
      expect(v.rating, 4.0);
    });
  });

  group('VendorCategory', () {
    test('fallback catalogue covers every requested category', () {
      final ids = VendorCategory.fallback.map((c) => c.id).toSet();
      expect(
        ids,
        containsAll(['food', 'grocery', 'bakery', 'flowers', 'pets',
                     'gifts', 'electronics']),
      );
    });

    test('localizedName falls back to French for an unknown locale', () {
      const c = VendorCategory(
          id: 'flowers', nameEn: 'Flowers', nameFr: 'Fleurs', nameAr: 'زهور',
          icon: '💐', colorHex: '#EC4899', sortOrder: 40);
      expect(c.localizedName('ar'), 'زهور');
      expect(c.localizedName('en'), 'Flowers');
      expect(c.localizedName('it'), 'Fleurs');
    });
  });
}
