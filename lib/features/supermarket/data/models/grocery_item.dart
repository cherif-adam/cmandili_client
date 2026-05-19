import 'grocery_category.dart';

class GroceryItem {
  final String id;
  final String supermarketId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final GroceryCategory category;
  final String unit; // kg, piece, liter, etc.
  final bool isOrganic;
  final bool isAvailable;
  final double? discountPrice;
  final DateTime? discountEndTime;
  final int? discountQuantity;

  const GroceryItem({
    required this.id,
    required this.supermarketId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.category,
    required this.unit,
    this.isOrganic = false,
    this.isAvailable = true,
    this.discountPrice,
    this.discountEndTime,
    this.discountQuantity,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] ?? '',
      supermarketId: json['supermarketId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: GroceryCategory.values.firstWhere(
        (e) => e.toString() == 'GroceryCategory.${json['category']}',
        orElse: () => GroceryCategory.vegetables,
      ),
      unit: json['unit'] ?? 'piece',
      isOrganic: json['isOrganic'] ?? false,
      isAvailable: json['isAvailable'] ?? true,
      discountPrice: json['discountPrice'] != null ? (json['discountPrice'] as num).toDouble() : null,
      discountEndTime: json['discountEndTime'] != null ? DateTime.parse(json['discountEndTime']) : null,
      discountQuantity: json['discountQuantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supermarketId': supermarketId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'price': price,
      'category': category.toString().split('.').last,
      'unit': unit,
      'isOrganic': isOrganic,
      'isAvailable': isAvailable,
      'discountPrice': discountPrice,
      'discountEndTime': discountEndTime?.toIso8601String(),
      'discountQuantity': discountQuantity,
    };
  }
}
