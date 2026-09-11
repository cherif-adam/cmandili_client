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
//   - Text messages (quadrilingual: FR / EN / Derja / Arabic)
//   - Image messages (base64 Vision)
//   - Intents: search_food | restaurant_search | shop_search | delivery_request
//              | track_order | greeting | general

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

  // ── No-results fallback ───────────────────────────────────────────────────
  // The LLM's own "message" for search_food/shop_search always reads as a
  // promise of results ("Voici les meilleures pizzas disponibles !") because
  // it's generated before the client ever runs the actual query — it has no
  // way to know in advance the search will come back empty. Previously an
  // empty products list just left that promise standing with nothing below
  // it (identical-looking to any other card-less reply, e.g. a greeting).
  // REPLACES rather than appends: keeping the LLM's "here you go" text next
  // to an explicit "nothing found" line would read as self-contradictory.
  // French-only for now, matching every other client-side fallback string in
  // this file (e.g. the generic/network/server error messages below) — the
  // edge function is the only place language detection actually happens.
  static const String _kNoResultsMessage =
      'Aucun résultat trouvé pour cette recherche, essayez autre chose 🔍';

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
      final kind = e is _ChatFailure ? e.kind : _ChatFailureKind.malformed;
      return ChatMessage(text: _errorMessageFor(kind), isUser: false);
    }

    String finalText = intent.message;
    List<ProductResult> products = [];
    switch (intent.intentRaw) {
      case 'search_food':
        products = await _queryFoodItems(intent);
        if (products.isEmpty) finalText = _kNoResultsMessage;
        break;
      case 'restaurant_search':
        products = await _queryRestaurants(intent);
        if (products.isEmpty) finalText = _kNoResultsMessage;
        break;
      case 'shop_search':
        products = await _queryShopItems(intent);
        if (products.isEmpty) finalText = _kNoResultsMessage;
        break;
      case 'delivery_request':
        finalText = await _appendRecipientHint(intent.message);
        products = [_buildDeliveryCard()];
        break;
      case 'track_order':
        finalText = await _buildOrderStatusReply(intent.message);
        break;
      default:
        // 'general' is also where Facture questions land (SYSTEM_PROMPT RULE
        // 2 routes them here — there's no dedicated intent for it, deliberately
        // not building one: see the restaurant_search vs facture/colis
        // investigation). Only touch the message when the raw text actually
        // looks facture-shaped, so off-topic redirects / disambiguation
        // questions / every other 'general' reply is left untouched.
        if (intent.intentRaw == 'general' && _looksLikeFactureQuestion(userText)) {
          finalText = await _appendBillTypeHint(intent.message);
        }
        break;
    }

    // Persist AFTER finalText is resolved so history restoration (chat re-open)
    // shows the same order-status text the user actually saw, not just the
    // LLM's bare "Je vérifie ça !" lead-in.
    _persistMessages(
      userText: imageFile != null
          ? '[Image] ${userText.isNotEmpty ? userText : "Identify this"}'
          : userText,
      aiReply: finalText,
    );

    return ChatMessage(
      text: finalText,
      isUser: false,
      intent: intent.intentRaw,
      products: products,
    );
  }

  // ── Error messages by failure kind ────────────────────────────────────────
  // Previously a single generic bubble regardless of cause. Distinguishes the
  // 3 things that can actually go wrong (see _ChatFailureKind / _callChatFunction).
  static String _errorMessageFor(_ChatFailureKind kind) => switch (kind) {
        _ChatFailureKind.network =>
          'Pas de connexion internet — vérifiez votre réseau et réessayez 📡',
        _ChatFailureKind.server =>
          "Notre assistant est momentanément indisponible — réessayez dans un instant 🔧",
        _ChatFailureKind.malformed =>
          'Réponse inattendue de notre serveur — réessayez 🔁',
      };

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
      // The edge function itself responded with a non-2xx (e.g. 502 when
      // BOTH OpenRouter and Gemini failed) — that's a server-side failure,
      // not a connectivity problem on the phone.
      throw _ChatFailure(
        _ChatFailureKind.server,
        'ai-chat Edge Function HTTP ${e.status}: ${e.details ?? e.reasonPhrase}',
      );
    } catch (e) {
      // Anything else here (no signal, DNS failure, the 60s timeout above,
      // socket reset, ...) — the request never got a real response at all.
      throw _ChatFailure(_ChatFailureKind.network, 'Network error: $e');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw _ChatFailure(
        _ChatFailureKind.malformed,
        'ai-chat returned an unexpected payload: $data',
      );
    }
    if (data.containsKey('error')) {
      // A well-formed { error, details? } from the function — also a
      // server-side failure (both providers down, misconfiguration, etc.).
      final details = data['details'];
      throw _ChatFailure(
        _ChatFailureKind.server,
        '${data['error']}${details != null ? '\n$details' : ''}',
      );
    }

    return _AiIntent.fromJson(data);
  }

  // ── Load history (restore chat on screen open) ────────────────────────────
  // _persistMessages has always written every turn to chat_messages, but
  // nothing ever read it back — every chat open started blank despite the
  // saved transcript. Returns newest-first (matches the screen's `reverse:
  // true` ListView directly); the screen derives the chronological (oldest-
  // first) _apiHistory shape itself by reversing this list.
  //
  // Secondary `is_user` sort: _persistMessages inserts [userRow, aiRow] in one
  // statement, so both share the exact same `now()` (frozen per-transaction in
  // Postgres) — without a tiebreaker a tied pair's order is undefined. Sorting
  // is_user ascending (false/model before true/user) within a tie places the
  // pair correctly in this newest-first list: [..., model_reply, user_msg, ...].
  Future<List<ChatMessage>> loadHistory({int limit = 40}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await _supabase
          .from('chat_messages')
          .select('text, is_user, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('is_user', ascending: true)
          .limit(limit) as List<dynamic>;

      return rows.cast<Map<String, dynamic>>().map((r) {
        return ChatMessage(
          text: (r['text'] ?? '') as String,
          isUser: (r['is_user'] ?? false) as bool,
        );
      }).toList();
    } catch (e) {
      debugPrint('AiChatService – loadHistory error: $e');
      return [];
    }
  }

  // ── Clear history ("Effacer la conversation") ─────────────────────────────
  // Permanently deletes every chat_messages row for this user — RLS ("Users
  // delete own chat messages", auth.uid() = user_id) already scopes this to
  // the caller's own rows, same as loadHistory's read. The screen is
  // responsible for confirming with the user before calling this and for
  // resetting its own local state (_messages/_apiHistory) on success.
  Future<bool> clearHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _supabase.from('chat_messages').delete().eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('AiChatService – clearHistory error: $e');
      return false;
    }
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

      // Build OR filter: explicit keyword + health-goal semantic terms.
      //
      // BUGFIX: this used to add goal terms ONLY when there was no explicit
      // keyword ("avoid over-broadening") — but the LLM almost always returns
      // BOTH together for a health-goal message (e.g. health_goal:"sport" +
      // keyword:"poulet"), per the system prompt's own few-shot examples. That
      // made the goal terms dead code in the one case they actually mattered:
      // Rule 4's health-goal search relied entirely on the LLM's one narrow
      // literal keyword, which real menu text usually doesn't contain
      // verbatim ("poulet" alone matched 1 item live; "protéines" matched 0)
      // — so a health-goal question would get a nutrition-advice reply with
      // silently EMPTY results, no cards, and no visible error. Unioning both
      // term sets (deduped) fixes this without touching ordinary food search
      // at all: goalTerms is only non-null when health_goal is actually set.
      final keywordParts = <String>[];
      final seenTerms = <String>{};
      void addKeywordTerm(String raw) {
        final t = raw.trim();
        if (t.isEmpty || !seenTerms.add(t.toLowerCase())) return;
        keywordParts.add('name.ilike.%$t%');
        keywordParts.add('description.ilike.%$t%');
      }

      if (intent.keyword != null && intent.keyword!.isNotEmpty) {
        for (final term in intent.keyword!.split(',')) {
          addKeywordTerm(term);
        }
      }
      final goalTerms = _healthGoalKeyword(intent.healthGoal);
      if (goalTerms != null) {
        for (final term in goalTerms.split(',')) {
          addKeywordTerm(term);
        }
      }
      if (keywordParts.isNotEmpty) {
        query = query.or(keywordParts.join(','));
      }

      final rows = await query.order('price', ascending: true).limit(20)
          as List<dynamic>;

      return rows
          // Drop closed restaurants entirely — is_open was already fetched
          // above but never checked, so a currently-closed place could be
          // recommended with no indication the user couldn't actually order
          // from it right now. Filtering (vs. showing a "closed" badge) keeps
          // every card the assistant returns immediately actionable; the
          // regular restaurant list elsewhere already handles browsing
          // closed places by opening hours.
          .where((r) =>
              r['restaurants'] != null &&
              (r['restaurants'] as Map<String, dynamic>)['is_open'] == true)
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

  // ── Query restaurants (restaurant_search intent) ──────────────────────────
  // A VENUE list, not a dish list. Before this, "best restaurant" / "resto près
  // de moi" had no code path at all — it fell through to search_food and came
  // back as individual dish cards, which is what it looked like it was doing
  // wrong. `restaurants` is publicly readable (RLS: SELECT USING true), so this
  // is a plain client read like the food/shop queries.
  Future<List<ProductResult>> _queryRestaurants(_AiIntent intent) async {
    try {
      var query = _supabase.from('restaurants').select('''
        id, name, description, image_url, rating, review_count,
        delivery_time_min, delivery_fee, is_open, categories
      ''').eq('is_open', true).not('is_blocked', 'is', true);

      // Single OR clause (repeated .or() calls AND together in PostgREST, which
      // isn't what we want) — mirrors _queryFoodItems' keyword handling.
      // `category` is matched against the text[] `categories` AND the name, so a
      // cuisine word still finds an obviously-named place even when the row was
      // never tagged (all rows are currently untagged).
      final orParts = <String>[];
      final cat = intent.category?.trim();
      if (cat != null && cat.isNotEmpty) {
        orParts.add('categories.cs.{$cat}');
        orParts.add('name.ilike.%$cat%');
      }
      final kw = intent.keyword?.trim();
      if (kw != null && kw.isNotEmpty) {
        orParts.add('name.ilike.%$kw%');
        orParts.add('description.ilike.%$kw%');
      }
      if (orParts.isNotEmpty) query = query.or(orParts.join(','));

      // Best-first: rating, then review count. Most rows are unrated (rating 0)
      // right now, so this quietly degrades to insertion order — the assistant's
      // message is written NOT to over-promise "top rated" (SYSTEM_PROMPT RULE 2D).
      final rows = await query
          .order('rating', ascending: false, nullsFirst: false)
          .order('review_count', ascending: false)
          .limit(15) as List<dynamic>;

      return rows.cast<Map<String, dynamic>>().map<ProductResult>((r) {
        return ProductResult(
          type: 'restaurant',
          id: (r['id'] ?? '').toString(),
          name: (r['name'] ?? '') as String,
          description: r['description'] as String?,
          price: 0.0,
          currency: 'TND',
          imageUrl: _resolveImageUrl(r['image_url']),
          sourceName: (r['name'] ?? '') as String,
          sourceId: (r['id'] ?? '').toString(),
          rating: (r['rating'] as num?)?.toDouble(),
          deliveryTime: (r['delivery_time_min'] as num?)?.toInt(),
          deliveryFee: (r['delivery_fee'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('AiChatService – restaurant query error: $e');
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
          // Same reasoning as the restaurant query above — drop closed shops.
          .where((r) =>
              r['supermarkets'] != null &&
              (r['supermarkets'] as Map<String, dynamic>)['is_open'] == true)
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
        sourceName: 'Amana Courier',
        rating: null,
      );

  // ── Colis personalization (delivery_request) ──────────────────────────────
  // Light touch, not a search: mention the user's most recently saved
  // recipient (courier_screen.dart already lets a driver save one after
  // delivery) so "how do I send a package" isn't purely generic when we
  // already know who they usually send to. No new intent, no cards — one
  // extra sentence appended to the existing explanation.
  Future<String> _appendRecipientHint(String leadIn) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return leadIn;
    try {
      final row = await _supabase
          .from('saved_recipients')
          .select('name')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final name = (row?['name'] as String?)?.trim();
      if (name == null || name.isEmpty) return leadIn;
      return "$leadIn\n\nD'ailleurs, tu as déjà $name enregistré comme destinataire — tu peux lui "
          'renvoyer un colis en un clic depuis la section Colis 📦';
    } catch (e) {
      debugPrint('AiChatService – recipient hint error: $e');
      return leadIn;
    }
  }

  // ── Facture personalization (general intent, facture-shaped text) ─────────
  // There's no "saved bill references" table (unlike saved_recipients for
  // colis), so this infers a pattern from past facture orders' bill_type
  // instead of a dedicated saved list. With only test data in the DB today
  // this mostly has nothing to say yet — it silently falls back to the plain
  // explanation, which is the correct behaviour, not a bug.
  bool _looksLikeFactureQuestion(String text) {
    final t = text.toLowerCase();
    const triggers = ['facture', 'fatoura', 'steg', 'sonede', 'topnet', 'bill', 'invoice'];
    return triggers.any(t.contains);
  }

  Future<String> _appendBillTypeHint(String leadIn) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return leadIn;
    try {
      final rows = await _supabase
          .from('orders')
          .select('bill_type')
          .eq('user_id', userId)
          .eq('order_type', 'facture')
          .not('bill_type', 'is', null)
          .order('created_at', ascending: false)
          .limit(20) as List<dynamic>;
      if (rows.isEmpty) return leadIn;

      // Most frequent bill_type in the last 20 factures; ties favour the more
      // recent one since rows arrive newest-first and reduce() keeps the
      // earlier-seen entry on a tie (b.value > a.value is false, so a wins).
      final counts = <String, int>{};
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final bt = (r['bill_type'] as String?)?.trim();
        if (bt != null && bt.isNotEmpty) counts[bt] = (counts[bt] ?? 0) + 1;
      }
      if (counts.isEmpty) return leadIn;
      final topType =
          counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;

      return '$leadIn\n\nTu payes souvent ta facture ${_billTypeLabel(topType)} par ici — dis-moi '
          "si c'est celle-ci 👍";
    } catch (e) {
      debugPrint('AiChatService – bill type hint error: $e');
      return leadIn;
    }
  }

  static String _billTypeLabel(String billType) => switch (billType.toLowerCase()) {
        'steg' => 'STEG',
        'sonede' => 'SONEDE',
        'topnet' => 'Topnet',
        _ => billType,
      };

  // ── Order tracking (track_order intent) ───────────────────────────────────
  // Client-side, same pattern as the food/shop queries above: plain
  // RLS-guarded reads against the customer's own session, no secret needed.
  // Deliberately does NOT attempt to resolve driver name/phone: profiles' RLS
  // only allows reading your OWN row (auth.uid() = id), so a customer-session
  // query for a driver's profile always returns nothing — the same reason
  // OrderRepository._mapOrderFromDb hardcodes driverName/driverPhone to null
  // today. Not attempting it here avoids a query that would just silently
  // fail; showing status + venue is what's actually reliable to promise.

  static const Set<String> _terminalOrderStatuses = {'delivered', 'cancelled'};

  /// The user's most recent NON-terminal order, or null if signed out, on any
  /// read error, or if their most recent orders are all delivered/cancelled.
  /// Shared by _buildOrderStatusReply and hasActiveOrder (chip context) so
  /// there's exactly one place that defines "what counts as active."
  Future<Map<String, dynamic>?> _fetchActiveOrderRow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final rows = await _supabase
          .from('orders')
          .select('id, status, order_type, restaurant_id, supermarket_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10) as List<dynamic>;

      final active = rows.cast<Map<String, dynamic>>().firstWhere(
            (o) => !_terminalOrderStatuses.contains(o['status']),
            orElse: () => const {},
          );
      return active.isEmpty ? null : active;
    } catch (e) {
      debugPrint('AiChatService – active order lookup error: $e');
      return null;
    }
  }

  /// Whether the user currently has an order in flight — used by the chat
  /// screen to decide whether to show a "Suivre ma commande" starter chip.
  /// Best-effort: any failure (including signed-out) reads as "no", which is
  /// the safe default — worst case a chip that would have been useful is
  /// simply not shown, never a chip promising a tracking result that isn't
  /// really there.
  Future<bool> hasActiveOrder() async => (await _fetchActiveOrderRow()) != null;

  Future<String> _buildOrderStatusReply(String leadIn) async {
    try {
      final active = await _fetchActiveOrderRow();
      if (active == null) {
        return "$leadIn\n\nVous n'avez pas de commande en cours actuellement 🙂";
      }

      final shortId = (active['id'] as String).substring(0, 8).toUpperCase();
      final status = (active['status'] ?? '') as String;
      final isFacture = active['order_type'] == 'facture';

      String? venueName;
      final restaurantId = active['restaurant_id'] as String?;
      final supermarketId = active['supermarket_id'] as String?;
      if (restaurantId != null) {
        final r = await _supabase
            .from('restaurants')
            .select('name')
            .eq('id', restaurantId)
            .maybeSingle();
        venueName = r?['name'] as String?;
      } else if (supermarketId != null) {
        final s = await _supabase
            .from('supermarkets')
            .select('name')
            .eq('id', supermarketId)
            .maybeSingle();
        venueName = s?['name'] as String?;
      }

      final buffer = StringBuffer(leadIn)
        ..write(isFacture ? '\n\n🧾 Facture #$shortId' : '\n\n📦 Commande #$shortId');
      if (venueName != null && venueName.isNotEmpty) buffer.write(' — $venueName');
      buffer.write('\nStatut : ${_orderStatusLabel(status, isFacture: isFacture)}');

      return buffer.toString();
    } catch (e) {
      debugPrint('AiChatService – order status lookup error: $e');
      return "$leadIn\n\nImpossible de récupérer le statut de votre commande pour le moment 😕";
    }
  }

  // isFacture branches the mid-lifecycle labels to match what the driver app
  // itself shows for a facture (order_tracking_screen.dart: "Espèces
  // collectées" at pickedUp) — a generic "Récupérée par le livreur 🛵" reads
  // like a package, which is confusing when nothing physical was picked up.
  static String _orderStatusLabel(String status, {bool isFacture = false}) => switch (status) {
        'pending' => 'En attente de confirmation ⏳',
        'confirmed' => 'Confirmée, en préparation 👨‍🍳',
        'preparing' => 'En préparation 👨‍🍳',
        'ready' => isFacture
            ? "En attente qu'un livreur se charge de votre facture 🧾"
            : "Prête, en attente d'un livreur 📦",
        'pickedUp' => isFacture
            ? 'Espèces collectées par le livreur 💵'
            : 'Récupérée par le livreur 🛵',
        'onTheWay' => isFacture
            ? 'Le livreur est en route pour payer votre facture 🧾'
            : 'En route vers vous 🛵',
        _ => status,
      };

  // ── Image URL resolver ────────────────────────────────────────────────────

  String? _resolveImageUrl(dynamic raw) {
    if (raw == null) return null;
    final url = raw.toString().trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$_storageBase$url';
  }
}

// ── Failure classification (distinct error messages, see sendMessage) ────────

enum _ChatFailureKind { network, server, malformed }

/// Thrown by _callChatFunction so sendMessage's catch can show a message
/// specific to what actually went wrong, instead of one generic bubble.
class _ChatFailure implements Exception {
  final _ChatFailureKind kind;
  final String detail;
  const _ChatFailure(this.kind, this.detail);
  @override
  String toString() => 'ChatFailure(${kind.name}): $detail';
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