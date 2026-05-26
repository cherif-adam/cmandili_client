// lib/models/chat_message.dart
import 'dart:io';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? intent;
  final List<ProductResult>? products;
  final File? imageFile; // ← user-sent image for bubble display

  ChatMessage({
    required this.text,
    required this.isUser,
    this.intent,
    this.products,
    this.imageFile,
  });
}

class ProductResult {
  final String type; // "food" | "shop" | "delivery"
  final String id;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final String? imageUrl;
  final String sourceName;
  final String? sourceId;      // ← restaurant/supermarket ID for navigation
  final double? rating;
  final int? deliveryTime;     // ← delivery time in minutes
  final double? deliveryFee;   // ← delivery fee in TND

  ProductResult({
    required this.type,
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    this.imageUrl,
    required this.sourceName,
    this.sourceId,
    this.rating,
    this.deliveryTime,
    this.deliveryFee,
  });

  factory ProductResult.fromJson(Map<String, dynamic> json) {
    return ProductResult(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'TND',
      imageUrl: json['image_url'],
      sourceName: json['source_name'] ?? '',
      sourceId: json['source_id'],
      rating: (json['rating'] as num?)?.toDouble(),
      deliveryTime: (json['delivery_time'] as num?)?.toInt(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
    );
  }
}