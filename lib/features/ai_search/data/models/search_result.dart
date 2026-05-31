import '../../../../core/utils/platform_pricing.dart';

/// Represents a single food item result returned from the AI search Edge Function.
/// The nested [restaurantName] / [restaurantImageUrl] / etc. come from the
/// embedded `restaurants` join in the Edge Function query.
class AiSearchFoodResult {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final String imageUrl;
  final String category;
  final bool isSpicy;
  final bool isVegetarian;
  final int preparationTime;
  final String restaurantId;
  final String restaurantName;
  final String? restaurantImageUrl;
  final double? restaurantRating;
  final int? deliveryTimeMin;
  final double? deliveryFee;
  final bool restaurantIsOpen;

  const AiSearchFoodResult({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountPrice,
    required this.imageUrl,
    required this.category,
    required this.isSpicy,
    required this.isVegetarian,
    required this.preparationTime,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantImageUrl,
    this.restaurantRating,
    this.deliveryTimeMin,
    this.deliveryFee,
    required this.restaurantIsOpen,
  });

  /// Effective client price: (discounted base if active, else base) + platform fee.
  double get effectivePrice => applyPlatformMarkup(discountPrice ?? price);

  factory AiSearchFoodResult.fromJson(Map<String, dynamic> json) {
    final restaurant = (json['restaurants'] as Map<String, dynamic>?) ?? {};
    return AiSearchFoodResult(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      imageUrl: (json['image_url'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      isSpicy: (json['is_spicy'] as bool?) ?? false,
      isVegetarian: (json['is_vegetarian'] as bool?) ?? false,
      preparationTime: (json['preparation_time'] as int?) ?? 15,
      restaurantId: (json['restaurant_id'] as String?) ?? '',
      restaurantName: (restaurant['name'] as String?) ?? '',
      restaurantImageUrl: restaurant['image_url'] as String?,
      restaurantRating: (restaurant['rating'] as num?)?.toDouble(),
      deliveryTimeMin: restaurant['delivery_time_min'] as int?,
      deliveryFee: (restaurant['delivery_fee'] as num?)?.toDouble(),
      restaurantIsOpen: (restaurant['is_open'] as bool?) ?? false,
    );
  }
}

/// Extracted intent from the conversational search (mode: text).
class TextSearchIntent {
  final String? category;
  final bool? spicy;
  final bool? vegetarian;
  final double? maxPrice;
  final double? minPrice;
  final String? deliveryTime;
  final String? keyword;

  const TextSearchIntent({
    this.category,
    this.spicy,
    this.vegetarian,
    this.maxPrice,
    this.minPrice,
    this.deliveryTime,
    this.keyword,
  });

  factory TextSearchIntent.fromJson(Map<String, dynamic> json) {
    return TextSearchIntent(
      category: json['category'] as String?,
      spicy: json['spicy'] as bool?,
      vegetarian: json['vegetarian'] as bool?,
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      minPrice: (json['min_price'] as num?)?.toDouble(),
      deliveryTime: json['delivery_time'] as String?,
      keyword: json['keyword'] as String?,
    );
  }

  /// Human-readable summary of extracted intent for display in the UI.
  String toReadableSummary() {
    final parts = <String>[];
    if (category != null && category != 'general') parts.add(category!);
    if (keyword != null) parts.add('"${keyword!}"');
    if (spicy == true) parts.add('🌶 Spicy');
    if (vegetarian == true) parts.add('🥦 Vegetarian');
    if (maxPrice != null) parts.add('≤ ${maxPrice!.toStringAsFixed(0)} TND');
    if (deliveryTime == 'fast') parts.add('⚡ Fast delivery');
    return parts.isEmpty ? 'All results' : parts.join(' · ');
  }
}

/// Top-level response from the ai-search Edge Function.
sealed class AiSearchResponse {
  const AiSearchResponse();
}

class AiTextSearchResponse extends AiSearchResponse {
  final TextSearchIntent intent;
  final List<AiSearchFoodResult> results;

  const AiTextSearchResponse({required this.intent, required this.results});
}

class AiImageSearchResponse extends AiSearchResponse {
  final String? dishName;
  final String confidence;
  final List<AiSearchFoodResult> results;

  const AiImageSearchResponse({
    required this.dishName,
    required this.confidence,
    required this.results,
  });
}
