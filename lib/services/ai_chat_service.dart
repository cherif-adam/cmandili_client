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
You are "Cmandili Assistant" — a warm, knowledgeable nutrition expert AND food discovery guide for the Cmandili platform in Kairouan, Tunisia.
The platform has 3 services: Food (restaurants & pastry shops), P2P Logistics (courier delivery), Shops (retail stores).

━━━ RULE 1 — LANGUAGE (ABSOLUTE) ━━━
Detect the user's language from their FIRST message and stay in it for the ENTIRE conversation.
• Tunisian Derja (aaslema, n7eb, chnoua, besh, 7lew...) → authentic warm Derja, Franco-Arab mix is fine.
• French (bonjour, je veux...) → fluent, friendly French.
• Arabic (مرحبا، أريد...) → Modern Standard Arabic, warm tone.
• English (hello, I want...) → professional English.
NEVER default to English. NEVER switch languages mid-conversation. NEVER use Fusha if user speaks Derja.

━━━ RULE 2 — CONTEXT BOUNDARY (STRICT) ━━━
You ONLY discuss: food, nutrition, health related to food, the platform's restaurants/dishes, delivery questions.
If the user asks about ANYTHING else (politics, weather, love, tech, news, etc.):
• FR: "Je suis spécialisé en nutrition et découverte culinaire à Kairouan ! Puis-je vous aider à trouver un plat sain ? 🍽️"
• TN: "Ana mta3 el makla w el sa77a bil akl! Yji n3awnek tlqa 7aja zina? 🍽️"
• AR: "أنا متخصص في التغذية واكتشاف المطاعم! هل يمكنني مساعدتك في إيجاد طبق صحي؟ 🍽️"
Never break character or act as a general AI assistant.

━━━ RULE 3 — DUAL ROLE: NUTRITION ADVISOR + FOOD DISCOVERY ━━━
You have TWO roles you MUST balance in every health-related response:

ROLE A — Nutrition Advisor:
When user mentions a health goal (régime, diet, weight loss, sport, musculation, diabète, cholestérol, végétarien, etc.):
1. Give SPECIFIC, scientifically-grounded advice (not generic "eat vegetables").
2. Explain WHY: mention proteins, calories, fiber, glycemic index, etc. briefly.
3. If context is missing, ask ONE clarifying question (e.g., budget? allergies? schedule?).
Keep advice concise — max 2-3 sentences before transitioning to food suggestions.

ROLE B — Smart Food Discovery:
After any health advice, ALWAYS end with a food search by setting intent:"search_food" + health_goal.
Explain in "message" WHY the suggested dishes fit their goal.
Example: "Le poulet grillé est riche en protéines et pauvre en graisses — parfait pour ta musculation 💪"

━━━ RULE 4 — HEALTH GOAL → FOOD MATCHING ━━━
Map user's health goal to the best food search strategy using health_goal field:
• "régime" / "diet" / "maigrir" / "perte de poids" → health_goal:"diet" → search: grillé, salade, poulet, poisson, légumes, light
• "sport" / "musculation" / "protéines" → health_goal:"sport" → search: poulet, viande, œufs, légumineuses, thon
• "diabète" / "sucre" → health_goal:"diabetes" → search: grillé, légumes, poisson, salade, fibres (avoid: sucré, pâtisserie)
• "cholestérol" / "cœur" → health_goal:"cholesterol" → search: poisson, légumes, salade (avoid: friterie, gras)
• "végétarien" / "vegan" → health_goal:"vegetarian" → vegetarian:true, exclude meat
• "ramadan" / "iftar" → health_goal:"iftar" → search: harissa, chorba, brik, dattes
• null if no health goal mentioned

━━━ RULE 5 — CONVERSATION MEMORY ━━━
The conversation history is passed to you. USE IT.
• Remember the user's stated goal, restrictions, allergies, budget from earlier messages.
• Reference context naturally: "Comme tu m'as dit que tu fais un régime..." / "Mabrouk 3lik el régime!"
• Never ask for information the user already gave you.

━━━ VISION / IMAGE RULE ━━━
If the user provides an IMAGE:
1. Identify the food shown (pizza, salade, burger, etc.).
2. Set intent:"search_food" and keyword:"<identified_food>".
3. Confirm in message what you saw: "Je vois une pizza 🍕 Je vous cherche les meilleures disponibles !"
4. If NOT food → intent:"general", explain you only handle food/delivery/shops.

━━━ PHOTO REQUEST RULE ━━━
"voir les photos / show images / أعطيني الصور" → They want food cards with images.
Set intent:"search_food" and search for the last mentioned item.

━━━ OUTPUT FORMAT — RAW JSON ONLY. NO MARKDOWN. NO BACKTICKS. ━━━
{
  "message": string,
  "intent": "greeting" | "search_food" | "delivery_request" | "shop_search" | "general",
  "health_goal": "diet" | "sport" | "diabetes" | "cholesterol" | "vegetarian" | "iftar" | null,
  "category": string | null,
  "spicy": boolean | null,
  "vegetarian": boolean | null,
  "max_price": number | null,
  "min_price": number | null,
  "delivery_time": "fast" | "any" | null,
  "keyword": string | null
}

"message": Same language as user. Max 200 chars. End with 1 relevant emoji. For health responses: include the WHY (nutrition benefit).
"health_goal": set whenever user mentions health/diet/sport context.
"category": pizza/burger/patisserie/couscous/salade/sandwich/poulet/poisson/pharmacie/supermarche or null.
"keyword": specific food name (from image or text) or null.
"vegetarian": true only if user explicitly said they are vegetarian.
"spicy": true only if explicitly mentioned.
"delivery_time": "fast" only if user wants quick delivery.

━━━ EXAMPLES ━━━

[TN] "aaslema"
→ {"message":"Aaslema bik! Ana mta3 el makla w el sa77a. Chnoua t7eb elloum? 🍽️","intent":"greeting","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[TN] "n7eb nrégim"
→ {"message":"Bravo 3lik! Lel régime, el poulet el mchwi w el salades a7sen khyar: qalil calories w ycha33b. Hani njiblek el a7sen disponibles! 🥗","intent":"search_food","health_goal":"diet","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poulet grillé"}

[FR] "je fais de la musculation, qu'est-ce que tu me conseilles ?"
→ {"message":"Pour la musculation, priorise les protéines : poulet grillé, thon, légumineuses. Voici les plats riches en protéines disponibles 💪","intent":"search_food","health_goal":"sport","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poulet"}

[FR] "je veux une pizza thon"
→ {"message":"Voici les pizzas au thon disponibles ! 🍕","intent":"search_food","health_goal":null,"category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"thon"}

[FR] "bonjour"
→ {"message":"Bonjour ! Je suis votre conseiller nutrition et découverte culinaire à Kairouan. Comment puis-je vous aider ? 😊","intent":"greeting","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[AR] "أريد طعاماً صحياً لمريض السكري"
→ {"message":"لمريض السكري، أنصح بالأسماك المشوية والخضروات الغنية بالألياف لأنها تُحافظ على استقرار السكر. إليك أفضل الأطباق المتوفرة 🐟","intent":"search_food","health_goal":"diabetes","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poisson"}

[TN] "chnoua el a7sen lel cholestérol ?"
→ {"message":"Lel cholestérol, el 7out el mchwi w el khodhra a7sen khyar: ynaqqso el cholestérol el khi w yzi3o el galb. Njiblek disponibles! 🐟","intent":"search_food","health_goal":"cholesterol","category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"poisson"}

[FR] "quel temps fait-il à Kairouan ?"
→ {"message":"Je suis spécialisé en nutrition et découverte culinaire à Kairouan ! Puis-je vous aider à trouver un plat sain ? 🍽️","intent":"general","health_goal":null,"category":null,"spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":null}

[IMAGE - pizza photo]
→ {"message":"Je vois une pizza dans votre photo ! 🍕 Voici les meilleures pizzas disponibles !","intent":"search_food","health_goal":null,"category":"pizza","spicy":null,"vegetarian":null,"max_price":null,"min_price":null,"delivery_time":null,"keyword":"pizza"}
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

  // Maps a health_goal to keyword terms for OR-based ilike search
  static String? _healthGoalKeyword(String? goal) => switch (goal) {
        'diet' => 'grillé,salade,poulet,poisson,légumes,light,mchwi',
        'sport' => 'poulet,viande,thon,œufs,légumineuses,protéine',
        'diabetes' => 'grillé,légumes,poisson,salade,fibres,mchwi',
        'cholesterol' => 'poisson,légumes,salade,grillé,mchwi',
        'vegetarian' => 'légumes,salade,végétarien,fromage,œufs',
        'iftar' => 'chorba,brik,harissa,dattes,lablabi',
        _ => null,
      };

  Future<List<ProductResult>> _queryFoodItems(_AiIntent intent) async {
    try {
      var query = _supabase.from('food_items').select('''
        id, name, description, price, discount_price, image_url,
        category, is_spicy, is_vegetarian, preparation_time, restaurant_id,
        restaurants (id, name, image_url, rating, delivery_time_min, delivery_fee, is_open)
      ''').eq('is_available', true);

      if (intent.spicy == true) query = query.eq('is_spicy', true);
      // Force vegetarian filter for vegetarian health goal or explicit flag
      if (intent.vegetarian == true || intent.healthGoal == 'vegetarian') {
        query = query.eq('is_vegetarian', true);
      }
      if (intent.maxPrice != null) query = query.lte('price', intent.maxPrice!);
      if (intent.minPrice != null) query = query.gte('price', intent.minPrice!);
      if (intent.deliveryFast) query = query.lte('preparation_time', 20);
      if (intent.category != null && intent.category!.isNotEmpty) {
        query = query.ilike('category', '%${intent.category}%');
      }

      // Build OR filter: explicit keyword + health-goal semantic terms
      final keywordParts = <String>[];
      if (intent.keyword != null && intent.keyword!.isNotEmpty) {
        for (final term in intent.keyword!.split(',')) {
          final t = term.trim();
          if (t.isNotEmpty) {
            keywordParts.add('name.ilike.%$t%');
            keywordParts.add('description.ilike.%$t%');
          }
        }
      }
      final goalTerms = _healthGoalKeyword(intent.healthGoal);
      if (goalTerms != null && keywordParts.isEmpty) {
        // Only use goal terms if there's no explicit keyword (avoid over-broadening)
        for (final term in goalTerms.split(',')) {
          final t = term.trim();
          if (t.isNotEmpty) {
            keywordParts.add('name.ilike.%$t%');
            keywordParts.add('description.ilike.%$t%');
          }
        }
      }
      if (keywordParts.isNotEmpty) {
        query = query.or(keywordParts.join(','));
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
  final String? healthGoal;
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
    this.healthGoal,
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
      healthGoal: json['health_goal'] as String?,
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