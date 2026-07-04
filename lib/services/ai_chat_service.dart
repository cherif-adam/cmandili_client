// lib/services/ai_chat_service.dart
//
// Cmandili AI Chat — client for the `ai-chat` Supabase Edge Function.
//
// The LLM call lives SERVER-SIDE (supabase/functions/ai-chat) so no AI
// provider key ever ships inside the app. This service sends the user's
// message (+ optional image + conversation history) to the function and maps
// the structured intent it returns; the food/grocery queries and product
// cards below still run client-side against plain RLS-guarded tables.
//
// Supports:
//   - Text messages (trilingual: FR / EN / Derja)
//   - Image messages (base64 Vision)
//   - Intents: search_food | delivery_request | shop_search | greeting | general

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class AiChatService {
  // ── Edge Function config ──────────────────────────────────────────────────

  static const String _functionName = 'ai-chat';

  // ── Supabase ──────────────────────────────────────────────────────────────

  final _supabase = Supabase.instance.client;

  static const String _storageBase =
      'https://hoqlxxtphskgxktqjpfu.supabase.co/storage/v1/object/public/';

  // ── System prompt ─────────────────────────────────────────────────────────
  // Lives SERVER-SIDE in supabase/functions/ai-chat/index.ts (SYSTEM_PROMPT),
  // ported verbatim from the old client-side implementation.


  // ── Public API ────────────────────────────────────────────────────────────

  /// [imageFile] is optional — if provided, sends image to Gemini Vision.
  Future<ChatMessage> sendMessage(
    String userText,
    List<Map<String, dynamic>> history, {
    File? imageFile,
  }) async {
    final _AiIntent intent;
    try {
      intent = await _callChatFunction(userText, history, imageFile: imageFile);
    } catch (e) {
      debugPrint('AiChatService – ai-chat function error: $e');
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

  // ── Edge Function call (text + optional vision) ───────────────────────────

  Future<_AiIntent> _callChatFunction(
    String userText,
    List<Map<String, dynamic>> history, {
    File? imageFile,
  }) async {
    String? imageBase64;
    String? mimeType;

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      imageBase64 = base64Encode(bytes);

      // Detect MIME type from extension
      final ext = imageFile.path.split('.').last.toLowerCase();
      mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
    }

    final FunctionResponse response;
    try {
      response = await _supabase.functions
          .invoke(
            _functionName,
            body: {
              'text': userText,
              // Gemini-style history [{role, parts:[{text}]}] — the function
              // converts it, giving the assistant real conversation memory.
              'history': history,
              if (imageBase64 != null) 'imageBase64': imageBase64,
              if (mimeType != null) 'mimeType': mimeType,
            },
          )
          .timeout(const Duration(seconds: 60)); // longer for vision
    } on FunctionException catch (e) {
      throw Exception(
        'ai-chat Edge Function HTTP ${e.status}: ${e.details ?? e.reasonPhrase}',
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('ai-chat returned an unexpected payload: $data');
    }
    if (data.containsKey('error')) {
      final details = data['details'];
      throw Exception('${data['error']}${details != null ? '\n$details' : ''}');
    }

    return _AiIntent.fromJson(data);
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

  /// Builds an intent from the JSON map the `ai-chat` Edge Function returns.
  factory _AiIntent.fromJson(Map<String, dynamic> json) {
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