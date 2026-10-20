// Shared by OrderRepository (one-off reads) and OrderLiveRepository
// (realtime streams): both turn raw `orders` rows into Order JSON.

/// La sélection commune à l'historique et au détail d'une commande.
///
/// `food_items` et `grocery_items` sont des vues sur `vendors`, et PostgREST
/// ne sait pas résoudre une jointure au travers : on vise les tables
/// sous-jacentes en gardant le nom de la vue comme alias, pour que le
/// mapping reste inchangé. `category` accompagne le nom du commerce parce
/// que c'est elle qui décide de la frise de suivi.
const String kOrderWithDetails =
    '*, restaurants:vendors!orders_restaurant_id_fkey(name, category), '
    'order_items(*, food_items:food_items_legacy(*), '
    'grocery_items:grocery_items_legacy(*), vendor_items(*))';

Map<String, dynamic> mapOrderFromDb(Map<String, dynamic> dbJson) {
  return {
    'id': dbJson['id'],
    'userId': dbJson['user_id'],
    'restaurantId': dbJson['restaurant_id'] ?? '',
    'restaurantName': (dbJson['restaurants'] is Map)
        ? (dbJson['restaurants']['name'] ?? '')
        : '',
    'shopCategory': (dbJson['restaurants'] is Map)
        ? dbJson['restaurants']['category']?.toString()
        : null,
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
    // Absent (so null) until 20261011120000_receipt_confirmation_and_
    // driver_ratings.sql has been run: the feature then stays hidden.
    'deliveredAt': dbJson['delivered_at'],
    'clientConfirmation': dbJson['client_confirmation'],
  };
}

/// Turn the joined `order_items` rows into the JSON shape
/// [CartItem.fromJson] expects. The raw DB rows are snake_case and carry
/// no product data of their own, so feeding them straight to CartItem
/// threw "type 'Null' is not a subtype of type 'Map<String, dynamic>'"
/// and failed the whole order history.
///
/// `order_items.price` is the price the customer actually paid, stored at
/// checkout. It is replayed as-is, so a past order always shows the amount
/// that was charged, even if the partner has changed his price since.
List<Map<String, dynamic>> _parseOrderItems(dynamic rawItems) {
  if (rawItems is! List) return [];
  final result = <Map<String, dynamic>>[];

  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final row = Map<String, dynamic>.from(raw);
    final quantity = (row['quantity'] as num?)?.toInt() ?? 1;
    final paidPrice = (row['price'] as num?)?.toDouble() ?? 0.0;

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
          'price': paidPrice, // order-time price, not today's menu price
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
          'price': paidPrice,
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
          'price': paidPrice,
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
        'price': paidPrice,
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
