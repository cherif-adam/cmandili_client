// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FoodItemImpl _$$FoodItemImplFromJson(Map<String, dynamic> json) =>
    _$FoodItemImpl(
      id: json['id'] as String,
      restaurantId: json['restaurant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      isAvailable: json['is_available'] as bool? ?? true,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      preparationTime: (json['preparation_time'] as num?)?.toInt() ?? 15,
      isVegetarian: json['is_vegetarian'] as bool? ?? false,
      isSpicy: json['is_spicy'] as bool? ?? false,
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      discountEndTime: json['discount_end_time'] == null
          ? null
          : DateTime.parse(json['discount_end_time'] as String),
      discountQuantity: (json['discount_quantity'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$FoodItemImplToJson(_$FoodItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'restaurant_id': instance.restaurantId,
      'name': instance.name,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'price': instance.price,
      'category': instance.category,
      'is_available': instance.isAvailable,
      'tags': instance.tags,
      'preparation_time': instance.preparationTime,
      'is_vegetarian': instance.isVegetarian,
      'is_spicy': instance.isSpicy,
      'discount_price': instance.discountPrice,
      'discount_end_time': instance.discountEndTime?.toIso8601String(),
      'discount_quantity': instance.discountQuantity,
    };
