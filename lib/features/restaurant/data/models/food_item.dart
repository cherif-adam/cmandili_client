class FoodItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final String category;
  final bool isAvailable;
  final List<String> tags;
  final int preparationTime; // in minutes
  final bool isVegetarian;
  final bool isSpicy;
  final double? discountPrice;
  final DateTime? discountEndTime;
  final int? discountQuantity;

  /// When the shop added this item. Null for rows read from somewhere that
  /// does not carry it (cart lines rebuilt from an order, etc.).
  final DateTime? createdAt;

  /// "Nouveau" for the first 24 hours after the shop adds it.
  bool get isNew =>
      createdAt != null &&
      DateTime.now().difference(createdAt!) < const Duration(hours: 24);

  FoodItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.category,
    this.isAvailable = true,
    this.tags = const [],
    this.preparationTime = 15,
    this.isVegetarian = false,
    this.isSpicy = false,
    this.discountPrice,
    this.discountEndTime,
    this.discountQuantity,
    this.createdAt,
  });

  /// Price shown to customers — exactly what the partner set.
  double get clientPrice => discountPrice ?? price;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
      tags: List<String>.from(json['tags'] ?? []),
      preparationTime: json['preparationTime'] ?? 15,
      isVegetarian: json['isVegetarian'] ?? false,
      isSpicy: json['isSpicy'] ?? false,
      discountPrice: json['discountPrice'] != null ? (json['discountPrice'] as num).toDouble() : null,
      discountEndTime: json['discountEndTime'] != null ? DateTime.parse(json['discountEndTime']) : null,
      discountQuantity: json['discountQuantity'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'price': price,
      'category': category,
      'isAvailable': isAvailable,
      'tags': tags,
      'preparationTime': preparationTime,
      'isVegetarian': isVegetarian,
      'isSpicy': isSpicy,
      'discountPrice': discountPrice,
      'discountEndTime': discountEndTime?.toIso8601String(),
      'discountQuantity': discountQuantity,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
