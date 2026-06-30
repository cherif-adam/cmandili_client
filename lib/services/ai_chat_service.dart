// lib/services/ai_chat_service.dart
//
// Cmandili AI Chat — fully client-side implementation.
//
// Supports:
//   - Text messages (trilingual: FR / EN / Derja)
//   - Image messages (base64 Vision via Gemini-1.5-flash)
//   - Intents: search_food | delivery_request | shop_search | greeting | general

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class AiChatService {
  // ── OpenRouter config ─────────────────────────────────────────────────────

  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  static String get _apiKey {
    final key = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    // Reject placeholder values that were left in the .env template
    if (key.isEmpty || key.contains('xxx') || key == 'YOUR_KEY_HERE') return '';
    return key;
  }

  // Use a vision-capable model for image support
  static String get _model =>
      dotenv.env['OPENROUTER_CHAT_MODEL'] ??
      'google/gemini-2.5-flash'; // ← vision-capable

  // ── Supabase ──────────────────────────────────────────────────────────────

  final _supabase = Supabase.instance.client;

  static const String _storageBase =
      'https://hoqlxxtphskgxktqjpfu.supabase.co/storage/v1/object/public/';

  // ── System prompt ─────────────────────────────────────────────────────────

  static String _buildSystemPrompt() => r'''
You are "Cmandili Assistant", the AI helper for the Cmandili platform in Tunisia.
The platform has 3 services: Food (restaurants & pastry shops), P2P Logistics (courier delivery), and Shops (retail stores).

━━━ CRITICAL LANGUAGE RULE ━━━
You are STRICTLY TRILINGUAL. Detect the user's language and reply ONLY in that SAME language.
- French (bonjour, je veux, tu parles...) → Reply in fluent, professional French.
- English (hello, I want, find...) → Reply in professional English.
- Tunisian Derja (aaslema, n7eb, chnoua...) → Reply in authentic warm Derja.
NEVER mix languages. NEVER use formal Arabic (Fusha). Default to French if unsure.

━━━ VISION / IMAGE RULE ━━━
If the user provides an IMAGE:
1. Carefully analyze the food/item shown in the image.
2. Identify what it is (e.g., "pizza", "salade", "burger", "patisserie").
3. Set "intent": "search_food" and "keyword": "<name_of_identified_food>".
4. In "message", confirm what you saw and tell the user you are searching for it.
   Example: "Je vois une pizza dans votre photo ! 🍕 Je vous cherche les meilleures pizzas disponibles !"
5. If the image is NOT food, set "intent": "general" and explain you only handle food/delivery/shops.

━━━ PHOTO/IMAGES REQUEST RULE ━━━
If the user asks to "see photos", "show images", "donner les photos", "أعطيني الصور" or similar:
- They want to SEE the food cards with images, NOT literal photos from the internet.
- Set intent: "search_food" (or "shop_search") and search for the last mentioned item.
- In message: confirm you are showing them the available items.

━━━ PLATFORM SERVICES ━━━
1. FOOD (search_food): Restaurants, pastry shops, sandwiches, Tunisian food
2. P2P DELIVERY (delivery_request): Send packages to friends/family via our drivers
3. SHOPS (shop_search): Retail stores, supermarkets, pharmacies

━━━ OUTPUT FORMAT ━━━
Respond with RAW JSON ONLY. No markdown, no backticks.
{
  "message": string,
  "intent": "greeting" | "search_food" | "delivery_request" | "shop_search" | "general",
  "category": string | null,
  "spicy": boolean | null,
  "vegetarian": boolean | null,
  "max_price": number | null,
  "min_price": number | null,
  "delivery_time": "fast" | "any" | null,
  "keyword": string | null
}

"message": Same language as user. Max 150 chars. End with 1 emoji.
"category": pizza/burger/patisserie/couscous/salade/sandwich/pharmacie/supermarche or null.
"keyword": specific item name (from image or text) or null.
"spicy"/"vegetarian": true only if explicitly mentioned.
"delivery_time": "fast" only if user wants quick delivery.
"max_price"/"min_price": price in TND as number or null.

━━━ EXAMPLES ━━━

[FR] "bonjour"
→ {"message":"Bonsoir ! Comment puis-je vous aider ? 😊","intent":"greeting","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[FR] "je veux une pizza thon"
→ {"message":"Voici les pizzas au thon disponibles ! 🍕","intent":"search_food","category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"thon"}

[FR] "donnez-moi les photos des salades"
→ {"message":"Voici les salades disponibles dans nos restaurants ! 🥗","intent":"search_food","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"salade"}

[EN] "hello"
→ {"message":"Hey there! How can I help you today? 😊","intent":"greeting","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[TN] "aaslema"
→ {"message":"Ayh sidi, aaslema! Chnoua t7eb elloum? 🍽️","intent":"greeting","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[TN] "n7eb pizza 7arra w ma tfoutch 15 dinar"
→ {"message":"Hani jitech bel pizzas el 7arrin! 🌶️🍕","intent":"search_food","category":"pizza","spicy":true,"vegetarian":null,"max_price":15,"min_price":null,"delivery_time":null,"keyword":null}

[IMAGE - pizza photo]
→ {"message":"Je vois une pizza dans votre photo ! 🍕 Voici les meilleures pizzas disponibles !","intent":"search_food","category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"pizza"}
''';

  // ── Public API ────────────────────────────────────────────────────────────

  /// [imageFile] is optional — if provided, sends image to Gemini Vision.
  Future<ChatMessage> sendMessage(
    String userText,
    List<Map<String, dynamic>> history, {
    File? imageFile,
  }) async {
    final _AiIntent intent;
    try {
      intent = await _callOpenRouter(userText, imageFile: imageFile);
    } catch (e) {
      debugPrint('AiChatService – OpenRouter error: $e');
      return ChatMessage(
        text: 'Une erreur est survenue 😕 Veuillez réessayer !',
        isUser: false,
      );
    }

    _persistMessages(
      userText: imageFile != null
          ? '[Image] ${userText.isNotEmpty ? userText : "Identify this"}'
          : userText,
      aiReply: intent.message,
    );

    List<ProductResult> products = [];
    switch (intent.intentRaw) {
      case 'search_food':
        products = await _queryFoodItems(intent);
        break;
      case 'shop_search':
        products = await _queryShopItems(intent);
        break;
      case 'delivery_request':
        products = [_buildDeliveryCard()];
        break;
      default:
        break;
    }

    return ChatMessage(
      text: intent.message,
      isUser: false,
      intent: intent.intentRaw,
      products: products,
    );
  }

  // ── OpenRouter call (text + optional vision) ──────────────────────────────

  Future<_AiIntent> _callOpenRouter(
    String userText, {
    File? imageFile,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OPENROUTER_API_KEY is missing in .env');
    }

    // Build the user content — text only, or text + image for Vision
    final List<Map<String, dynamic>> userContent;

    if (imageFile != null) {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Detect MIME type from extension
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };

      userContent = [
        // Text part (can be empty when only image is sent)
        if (userText.isNotEmpty)
          {'type': 'text', 'text': userText},
        // Image part — OpenRouter/Gemini Vision format
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mimeType;base64,$base64Image',
          },
        },
      ];
    } else {
      userContent = [
        {'type': 'text', 'text': userText},
      ];
    }

    final body = jsonEncode({
      'model': _model,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': _buildSystemPrompt()},
        {'role': 'user', 'content': userContent},
      ],
      'temperature': 0.4,
      'max_tokens': 512,
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://cmandili.com',
              'X-Title': 'Cmandili Mobile',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45)); // longer for vision
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode != 200) {
      debugPrint('OpenRouter HTTP ${response.statusCode}: ${response.body}');
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Invalid or missing OPENROUTER_API_KEY (HTTP ${response.statusCode})');
      }
      throw Exception('OpenRouter error (${response.statusCode})');
    }

    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        envelope['choices']?[0]?['message']?['content'] as String?;

    if (content == null || content.trim().isEmpty) {
      throw Exception('OpenRouter returned an empty response.');
    }

    return _AiIntent.parse(content);
  }

  // ── Persist messages ──────────────────────────────────────────────────────

  Future<void> _persistMessages({
    required String userText,
    required String aiReply,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('chat_messages').insert([
        {'user_id': userId, 'text': userText, 'is_user': true},
        {'user_id': userId, 'text': aiReply, 'is_user': false},
      ]);
    } catch (e) {
      debugPrint('AiChatService – persist error: $e');
    }
  }

  // ── Query food_items ──────────────────────────────────────────────────────

  Future<List<ProductResult>> _queryFoodItems(_AiIntent intent) async {
    try {
      var query = _supabase.from('food_items').select('''
        id, name, description, price, discount_price, image_url,
        category, is_spicy, is_vegetarian, preparation_time, restaurant_id,
        restaurants (id, name, image_url, rating, delivery_time_min, delivery_fee, is_open)
      ''').eq('is_available', true);

      if (intent.spicy == true) query = query.eq('is_spicy', true);
      if (intent.vegetarian == true) query = query.eq('is_vegetarian', true);
      if (intent.maxPrice != null) query = query.lte('price', intent.maxPrice!);
      if (intent.minPrice != null) query = query.gte('price', intent.minPrice!);
      if (intent.deliveryFast) query = query.lte('preparation_time', 20);
      if (intent.category != null && intent.category!.isNotEmpty) {
        query = query.ilike('category', '%${intent.category}%');
      }
      if (intent.keyword != null && intent.keyword!.isNotEmpty) {
        query = query.or(
          'name.ilike.%${intent.keyword}%,description.ilike.%${intent.keyword}%',
        );
      }

      final rows = await query.order('price', ascending: true).limit(20)
          as List<dynamic>;

      return rows
          .where((r) => r['restaurants'] != null)
          .map<ProductResult>((r) {
        final restaurant = r['restaurants'] as Map<String, dynamic>;
        return ProductResult(
          type: 'food',
          id: (r['id'] ?? '').toString(),
          name: (r['name'] ?? '') as String,
          description: r['description'] as String?,
          price:
              ((r['discount_price'] ?? r['price']) as num?)?.toDouble() ?? 0.0,
          currency: 'TND',
          imageUrl: _resolveImageUrl(r['image_url']),
          sourceName: (restaurant['name'] ?? '') as String,
          sourceId: (restaurant['id'] ?? '').toString(),
          rating: (restaurant['rating'] as num?)?.toDouble(),
          deliveryTime: (restaurant['delivery_time_min'] as num?)?.toInt(),
          deliveryFee:
              (restaurant['delivery_fee'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('AiChatService – food query error: $e');
      return [];
    }
  }

  // ── Query grocery_items ───────────────────────────────────────────────────

  Future<List<ProductResult>> _queryShopItems(_AiIntent intent) async {
    try {
      var query = _supabase.from('grocery_items').select('''
        id, name, description, price, discount_price, image_url, category,
        supermarkets (id, name, image_url, rating, is_open)
      ''').eq('is_available', true);

      if (intent.maxPrice != null) query = query.lte('price', intent.maxPrice!);
      if (intent.minPrice != null) query = query.gte('price', intent.minPrice!);
      if (intent.category != null && intent.category!.isNotEmpty) {
        query = query.ilike('category', '%${intent.category}%');
      }
      if (intent.keyword != null && intent.keyword!.isNotEmpty) {
        query = query.or(
          'name.ilike.%${intent.keyword}%,description.ilike.%${intent.keyword}%',
        );
      }

      final rows = await query.order('price', ascending: true).limit(20)
          as List<dynamic>;

      return rows
          .where((r) => r['supermarkets'] != null)
          .map<ProductResult>((r) {
        final shop = r['supermarkets'] as Map<String, dynamic>;
        return ProductResult(
          type: 'shop',
          id: (r['id'] ?? '').toString(),
          name: (r['name'] ?? '') as String,
          description: r['description'] as String?,
          price:
              ((r['discount_price'] ?? r['price']) as num?)?.toDouble() ?? 0.0,
          currency: 'TND',
          imageUrl: _resolveImageUrl(r['image_url']),
          sourceName: (shop['name'] ?? '') as String,
          sourceId: (shop['id'] ?? '').toString(),
          rating: (shop['rating'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('AiChatService – shop query error: $e');
      return [];
    }
  }

  // ── Delivery P2P card ─────────────────────────────────────────────────────

  ProductResult _buildDeliveryCard() => ProductResult(
        type: 'delivery',
        id: 'p2p_delivery',
        name: 'Livraison P2P',
        description:
            'Envoyez vos colis à vos proches via nos livreurs. Suivi en temps réel !',
        price: 0.0,
        currency: 'TND',
        imageUrl: null,
        sourceName: 'Cmandili Courier',
        rating: null,
      );

  // ── Image URL resolver ────────────────────────────────────────────────────

  String? _resolveImageUrl(dynamic raw) {
    if (raw == null) return null;
    final url = raw.toString().trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$_storageBase$url';
  }
}

// ── Internal intent model ─────────────────────────────────────────────────────

class _AiIntent {
  final String message;
  final String intentRaw;
  final String? category;
  final String? keyword;
  final bool? spicy;
  final bool? vegetarian;
  final num? maxPrice;
  final num? minPrice;
  final String? deliveryTime;

  bool get deliveryFast => deliveryTime == 'fast';

  const _AiIntent({
    required this.message,
    required this.intentRaw,
    this.category,
    this.keyword,
    this.spicy,
    this.vegetarian,
    this.maxPrice,
    this.minPrice,
    this.deliveryTime,
  });

  factory _AiIntent.parse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(json)?', multiLine: false), '')
          .replaceAll('```', '')
          .trim();
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('_AiIntent.parse – JSON decode failed: $e\nRaw: $raw');
      return const _AiIntent(
        message: 'Je suis là pour vous aider ! 😊',
        intentRaw: 'general',
      );
    }

    return _AiIntent(
      message: (json['message'] as String?)?.trim().isNotEmpty == true
          ? json['message'] as String
          : 'Comment puis-je vous aider ? 😊',
      intentRaw: (json['intent'] as String?) ?? 'general',
      category: json['category'] as String?,
      keyword: json['keyword'] as String?,
      spicy: json['spicy'] as bool?,
      vegetarian: json['vegetarian'] as bool?,
      maxPrice: json['max_price'] as num?,
      minPrice: json['min_price'] as num?,
      deliveryTime: json['delivery_time'] as String?,
    );
  }
}