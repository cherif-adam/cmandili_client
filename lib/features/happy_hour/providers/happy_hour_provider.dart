import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../restaurant/data/models/food_item.dart';
import '../../supermarket/data/models/grocery_item.dart';
import '../../supermarket/data/models/grocery_category.dart';

// Queries food_items where discount_price is set and discount_end_time is in the future
final happyHourRestaurantsProvider = FutureProvider<List<FoodItem>>((ref) async {
  final supabase = Supabase.instance.client;
  final now = DateTime.now().toIso8601String();

  final response = await supabase
      .from('food_items')
      .select()
      .not('discount_price', 'is', null)
      .gt('discount_end_time', now)
      .eq('is_available', true)
      .order('discount_end_time', ascending: true);

  return (response as List).map((json) => FoodItem(
    id: json['id'] ?? '',
    restaurantId: json['restaurant_id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    imageUrl: json['image_url'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    category: json['category'] ?? '',
    isAvailable: json['is_available'] ?? true,
    tags: List<String>.from(json['tags'] ?? []),
    preparationTime: json['preparation_time'] ?? 15,
    isVegetarian: json['is_vegetarian'] ?? false,
    isSpicy: json['is_spicy'] ?? false,
    discountPrice: json['discount_price'] != null
        ? (json['discount_price'] as num).toDouble()
        : null,
    discountEndTime: json['discount_end_time'] != null
        ? DateTime.parse(json['discount_end_time'])
        : null,
    discountQuantity: json['discount_quantity'],
  )).toList();
});

// Queries grocery_items where discount_price is set and discount_end_time is in the future
final happyHourSupermarketsProvider = FutureProvider<List<GroceryItem>>((ref) async {
  final supabase = Supabase.instance.client;
  final now = DateTime.now().toIso8601String();

  final response = await supabase
      .from('grocery_items')
      .select()
      .not('discount_price', 'is', null)
      .gt('discount_end_time', now)
      .eq('is_available', true)
      .order('discount_end_time', ascending: true);

  return (response as List).map((json) => GroceryItem(
    id: json['id'] ?? '',
    supermarketId: json['supermarket_id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    imageUrl: json['image_url'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    category: GroceryCategory.values.firstWhere(
      (e) => e.toString().split('.').last == (json['category'] ?? ''),
      orElse: () => GroceryCategory.vegetables,
    ),
    unit: json['unit'] ?? 'piece',
    isOrganic: json['is_organic'] ?? false,
    isAvailable: json['is_available'] ?? true,
    discountPrice: json['discount_price'] != null
        ? (json['discount_price'] as num).toDouble()
        : null,
    discountEndTime: json['discount_end_time'] != null
        ? DateTime.parse(json['discount_end_time'])
        : null,
    discountQuantity: json['discount_quantity'],
  )).toList();
});
