// lib/models/chat_message.dart

class ChatMessage {
  final String text;
  final bool isUser;
  final String? intent;
  final List<ProductResult>? products;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.intent,
    this.products,
  });
}

class ProductResult {
  final String type; // "food" | "grocery" | "merchant"
  final String id;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final String? imageUrl;
  final String sourceName;

  ProductResult({
    required this.type,
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    this.imageUrl,
    required this.sourceName,
  });

  factory ProductResult.fromJson(Map<String, dynamic> json) {
    return ProductResult(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'DZD',
      imageUrl: json['image_url'],
      sourceName: json['source_name'] ?? '',
    );
  }
}