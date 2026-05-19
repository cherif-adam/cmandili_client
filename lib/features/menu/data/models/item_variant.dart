/// One named option for a food/grocery item with its own price.
///
/// Examples: "Chocolate cake — 8 DT", "Vanilla cake — 7 DT", "Strawberry — 9 DT".
/// Items with no variants fall back to the base `food_items.price` /
/// `grocery_items.price`. Items with variants force the customer to pick
/// exactly one before adding to cart.
class ItemVariant {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;
  final int sortOrder;

  const ItemVariant({
    required this.id,
    required this.name,
    required this.price,
    this.isAvailable = true,
    this.sortOrder = 0,
  });

  factory ItemVariant.fromDb(Map<String, dynamic> row) {
    return ItemVariant(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      price: (row['price'] as num?)?.toDouble() ?? 0.0,
      isAvailable: row['is_available'] as bool? ?? true,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
      };

  factory ItemVariant.fromJson(Map<String, dynamic> json) {
    return ItemVariant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
