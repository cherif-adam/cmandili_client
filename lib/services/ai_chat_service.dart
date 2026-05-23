// lib/services/ai_chat_service.dart
//
// Cmandili AI Chat — fully client-side implementation.
//
// Flow for every user message:
//   1. Call OpenRouter (Gemini) with the system prompt → get structured JSON.
//   2. Persist user message + AI reply to `chat_messages` in Supabase.
//   3. If intent == "search_food" → query `food_items` ⨯ `restaurants` directly.
//   4. Return a ChatMessage to the UI.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class AiChatService {
  // ── OpenRouter config ────────────────────────────────────────────────────────

  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  /// Reads the key from .env (same file the rest of the app uses).
  static String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';

  /// Model to use. Override in .env with OPENROUTER_CHAT_MODEL if needed.
  static String get _model =>
      dotenv.env['OPENROUTER_CHAT_MODEL'] ?? 'google/gemini-2.0-flash-001';

  // ── Supabase client ──────────────────────────────────────────────────────────

  final _supabase = Supabase.instance.client;

  // ── Supabase Storage base (for resolving relative image_url paths) ───────────

  static const String _storageBase =
      'https://hoqlxxtphskgxktqjpfu.supabase.co/storage/v1/object/public/';

  // ── System prompt ────────────────────────────────────────────────────────────

  static const String _systemPrompt = '''
You are "Cmandili Assistant", a friendly AI for a Tunisian food-delivery app.
Your job is to understand the user's message, reply naturally in their language, and extract any food search intent.

━━━ LANGUAGE RULES ━━━
- Detect the language automatically from the user's message.
- If the user writes in Tunisian Darija (e.g. "aaslema", "n7eb", "7aja"), reply ENTIRELY in Tunisian Derja.
- If the user writes in French (e.g. "bonsoir", "je veux"), reply ENTIRELY in French.
- If the user writes in English, reply ENTIRELY in English.
- NEVER mix languages in the "message" field.

━━━ DARIJA GLOSSARY ━━━
- "aaslema / salam / bonsoir / bonne nuit / hello" → greeting
- "n7eb nekel / nbghi nakol / nheb / je veux / I want" → I want to eat
- "7arra / harr / épicé / spicy" → spicy: true
- "bila la7em / végétarien / vegetarian" → vegetarian: true
- "fissa3 / sari3 / rapide / fast" → delivery_time: "fast"
- "ma tfoutch X dinar / moins de X / under X" → max_price: X
- "pizza / burger / couscous / sandwich / kafteji / lablabi / fricassee" → category or keyword

━━━ OUTPUT RULES — CRITICAL ━━━
Respond with RAW JSON ONLY. No explanation, no markdown, no backticks.
The JSON MUST strictly conform to this schema:
{
  "message": string,
  "intent": "greeting" | "search_food" | "general",
  "category": string | null,
  "spicy": boolean | null,
  "vegetarian": boolean | null,
  "max_price": number | null,
  "min_price": number | null,
  "delivery_time": "fast" | "any" | null,
  "keyword": string | null
}

━━━ FIELD RULES ━━━
"message":
  - Greeting → warm reply in the user's language. E.g. "Bonsoir ! Comment puis-je vous aider ? 😊" / "Aaslema ! Chnowa t7eb takol ? 🍽️"
  - Food search → short enthusiastic confirmation. E.g. "Voilà les pizzas au thon ! 🍕"
  - General → answer helpfully.
  - ALWAYS end with 1 emoji. Keep under 120 characters.

"intent":
  - "greeting"    → user is ONLY greeting, no food request ("bonsoir", "aaslema", "merci")
  - "search_food" → user wants to find or order food
  - "general"     → other (question, complaint, etc.)

"category": main food category in English (e.g. "pizza", "burger", "couscous") or null.
"keyword": specific dish name or key ingredient (e.g. "thon", "fromage") or null.
"spicy", "vegetarian": true only if explicitly mentioned, otherwise null.
"delivery_time": "fast" only if user wants quick delivery, otherwise null.
"max_price", "min_price": price in TND as a number, or null.

━━━ EXAMPLES ━━━
User: "bonsoir"
→ {"message":"Bonsoir ! Comment puis-je vous aider ce soir ? 😊","intent":"greeting","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

User: "aaslema"
→ {"message":"Aaslema ! Chnowa t7eb takol elloum ? 🍽️","intent":"greeting","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

User: "je veux un pizza thon"
→ {"message":"Voilà les pizzas au thon disponibles près de chez vous ! 🍕","intent":"search_food","category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"thon"}

User: "n7eb 7aja 7arra w ma tfoutch 15 dinar"
→ {"message":"Nlqilek 7aja 7arra w rkhisa ! 🌶️","intent":"search_food","category":null,"spicy":true,"vegetarian":null,"max_price":15,"min_price":null,"delivery_time":null,"keyword":null}
''';

  // ── Public API ───────────────────────────────────────────────────────────────

  Future<ChatMessage> sendMessage(
    String userText,
    List<Map<String, dynamic>> history, // kept for API compatibility, unused
  ) async {
    // ── 1. Call OpenRouter ─────────────────────────────────────────────────────
    final _AiIntent intent;
    try {
      intent = await _callOpenRouter(userText);
    } catch (e) {
      debugPrint('AiChatService – OpenRouter error: $e');
      return ChatMessage(
        text: "Désolé, je n'arrive pas à te répondre pour le moment 😕 Réessaie !",
        isUser: false,
      );
    }

    // ── 2. Persist both turns to Supabase (fire-and-forget, non-blocking) ──────
    _persistMessages(userText: userText, aiReply: intent.message);

    // ── 3. Query food_items only when the AI thinks the user wants food ─────────
    List<ProductResult> products = [];
    if (intent.isSearchFood) {
      products = await _queryFoodItems(intent);
    }

    return ChatMessage(
      text: intent.message,
      isUser: false,
      intent: intent.intentRaw,
      products: products,
    );
  }

  // ── OpenRouter call ──────────────────────────────────────────────────────────

  Future<_AiIntent> _callOpenRouter(String userText) async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'OPENROUTER_API_KEY is missing — add it to your .env file.');
    }

    final body = jsonEncode({
      'model': _model,
      // Instructs compatible models to emit valid JSON.
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': userText},
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
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('Network error reaching OpenRouter: $e');
    }

    if (response.statusCode != 200) {
      debugPrint('OpenRouter ${response.statusCode}: ${response.body}');
      throw Exception('OpenRouter error (${response.statusCode})');
    }

    // Extract the assistant message content from the OpenRouter envelope
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        envelope['choices']?[0]?['message']?['content'] as String?;

    if (content == null || content.trim().isEmpty) {
      throw Exception('OpenRouter returned an empty response.');
    }

    return _AiIntent.parse(content);
  }

  // ── Supabase: persist messages ───────────────────────────────────────────────

  Future<void> _persistMessages({
    required String userText,
    required String aiReply,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return; // Not logged in → skip silently

    try {
      await _supabase.from('chat_messages').insert([
        {
          'user_id': userId,
          'text': userText,
          'is_user': true,
        },
        {
          'user_id': userId,
          'text': aiReply,
          'is_user': false,
        },
      ]);
    } catch (e) {
      // Non-critical — don't surface this to the user
      debugPrint('AiChatService – failed to persist messages: $e');
    }
  }

  // ── Supabase: query food_items ────────────────────────────────────────────────

  Future<List<ProductResult>> _queryFoodItems(_AiIntent intent) async {
    try {
      // Build the base query with the restaurant join
      var query = _supabase.from('food_items').select('''
        id,
        name,
        description,
        price,
        discount_price,
        image_url,
        category,
        is_spicy,
        is_vegetarian,
        preparation_time,
        restaurant_id,
        restaurants (
          id,
          name,
          image_url,
          rating,
          delivery_time_min,
          delivery_fee,
          is_open
        )
      ''').eq('is_available', true);

      // Apply filters extracted by the AI
      if (intent.spicy == true) {
        query = query.eq('is_spicy', true);
      }
      if (intent.vegetarian == true) {
        query = query.eq('is_vegetarian', true);
      }
      if (intent.maxPrice != null) {
        query = query.lte('price', intent.maxPrice!);
      }
      if (intent.minPrice != null) {
        query = query.gte('price', intent.minPrice!);
      }
      if (intent.deliveryFast) {
        query = query.lte('preparation_time', 20);
      }
      if (intent.category != null && intent.category != 'general') {
        query = query.ilike('category', '%${intent.category}%');
      }
      if (intent.keyword != null) {
        query = query.or(
          'name.ilike.%${intent.keyword}%,'
          'description.ilike.%${intent.keyword}%',
        );
      }

      final rows = await query
          .order('price', ascending: true)
          .limit(20) as List<dynamic>;

      return rows
          .where((r) => r['restaurants'] != null)
          .map<ProductResult>((r) {
            final restaurant = r['restaurants'] as Map<String, dynamic>;
            return ProductResult(
              type: 'food',
              id: (r['id'] ?? '').toString(),
              name: (r['name'] ?? '') as String,
              description: r['description'] as String?,
              price: ((r['discount_price'] ?? r['price']) as num?)
                      ?.toDouble() ??
                  0.0,
              currency: 'TND',
              imageUrl: _resolveImageUrl(r['image_url']),
              sourceName: (restaurant['name'] ?? '') as String,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('AiChatService – food query error: $e');
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Resolves image URLs from the DB:
  /// - Already http/https → use as-is.
  /// - Relative path     → prepend Supabase Storage base URL.
  /// - Null / empty      → return null (UI shows placeholder).
  String? _resolveImageUrl(dynamic raw) {
    if (raw == null) return null;
    final url = raw.toString().trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$_storageBase$url';
  }
}

// ── Internal model ────────────────────────────────────────────────────────────

/// Holds the parsed Gemini JSON response.
class _AiIntent {
  final String message;
  final String intentRaw; // "greeting" | "search_food" | "general"
  final String? category;
  final String? keyword;
  final bool? spicy;
  final bool? vegetarian;
  final num? maxPrice;
  final num? minPrice;
  final String? deliveryTime; // "fast" | "any" | null

  bool get isSearchFood => intentRaw == 'search_food';
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

  /// Parses the raw JSON string from OpenRouter.
  /// Strips markdown fences defensively in case the model ignores instructions.
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
      // Return a graceful fallback so the app never crashes
      return _AiIntent(
        message: "Je suis là pour vous aider ! 😊",
        intentRaw: 'general',
      );
    }

    return _AiIntent(
      message: (json['message'] as String?)?.trim().isNotEmpty == true
          ? json['message'] as String
          : "Je suis là pour vous aider ! 😊",
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