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
import '../core/utils/delivery_fee.dart';
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

  // ── Catalogue unreachable ─────────────────────────────────────────────────
  // Said when the query itself FAILED, which is a different thing from the
  // catalogue having nothing: we don't know what it has. Keeping the two
  // apart is the whole point — a PostgREST 400 used to be reported with
  // _kNoResultsMessage above, which reads as a fact about the catalogue and
  // sent everyone looking for missing data instead of a broken query.
  // Deliberately says nothing about what was or wasn't found.
  static const String _kQueryFailedMessage =
      'Je n\'ai pas pu interroger le catalogue — réessayez dans un instant 🔧';

  /// The message shown when a catalogue query fails, as opposed to coming
  /// back empty. Exposed so a test can assert the two never collapse into
  /// one another again.
  static String queryFailedMessage() => _kQueryFailedMessage;

  // ── Shop catalogues ───────────────────────────────────────────────────────
  // The 7 `vendors.category` slugs, mirroring `vendor_categories.id` and
  // ServiceTypeX.vendorCategory. The edge function sends one in
  // `service_category`; everything below turns it into a real query, a label
  // and an honest empty-state line.
  static const List<String> kServiceCategories = [
    'food',
    'grocery',
    'bakery',
    'flowers',
    'pets',
    'gifts',
    'electronics',
  ];

  /// What the user actually called the shop, for the empty-state line.
  static const Map<String, String> _kCategoryLabel = {
    'food': 'restaurant',
    'grocery': 'supermarché',
    'bakery': 'pâtisserie',
    'flowers': 'fleuriste',
    'pets': 'animalerie',
    'gifts': 'magasin de cadeaux',
    'electronics': 'magasin d\'électronique',
  };

  /// Same shops, carrying their French article — "le fleuriste", not "la".
  static const Map<String, String> _kCategoryWithArticle = {
    'food': 'le restaurant',
    'grocery': 'le supermarché',
    'bakery': 'la pâtisserie',
    'flowers': 'le fleuriste',
    'pets': 'l\'animalerie',
    'gifts': 'le magasin de cadeaux',
    'electronics': 'le magasin d\'électronique',
  };

  /// Nearest catalogue to point at when one comes back empty. Deliberately a
  /// sibling that plausibly carries something similar — never a promise that
  /// it does, the wording below stays conditional.
  static const Map<String, String> _kCategoryNeighbour = {
    'grocery': 'food',
    'bakery': 'food',
    'flowers': 'gifts',
    'gifts': 'flowers',
    'pets': 'grocery',
    'electronics': 'gifts',
  };

  /// Accepts only a known slug, with the same aliases the edge function maps,
  /// so an older function build that sends "supermarket" or "animalerie" in
  /// the field still lands on the right catalogue. Returns null for anything
  /// else rather than guessing — an unknown slug would query nothing.
  static String? normaliseServiceCategory(Object? raw) {
    if (raw is! String) return null;
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    const aliases = <String, String>{
      'supermarket': 'grocery',
      'supermarche': 'grocery',
      'groceries': 'grocery',
      'patisserie': 'bakery',
      'pastry': 'bakery',
      'flower': 'flowers',
      'pet': 'pets',
      'animalerie': 'pets',
      'gift': 'gifts',
      'cadeaux': 'gifts',
      'electronic': 'electronics',
      'restaurant': 'food',
    };
    final mapped = aliases[s] ?? s;
    return kServiceCategories.contains(mapped) ? mapped : null;
  }

  // Keyword → catalogue, used ONLY as the backward-compatibility fallback
  // below. Terms are lowercase and accent-stripped before matching, so
  // "litière" and "litiere" both hit. Order matters: the first catalogue with
  // a hit wins, so the lists are kept disjoint enough not to fight each other.
  static const Map<String, List<String>> _kCategoryKeywords = {
    'flowers': [
      'fleur', 'bouquet', 'rose', 'fleuriste', 'zhour', 'zhar', 'flower',
      'orchidee', 'plante', 'زهور', 'ورد',
    ],
    'pets': [
      // No bare 'laisse' (leash): it collides with the verb laisser
      // ("laisse tomber"), which has nothing to do with pets.
      'animalerie', 'croquette', 'litiere', 'chiot', 'chaton',
      'pour chat', 'pour chien', 'mon chat', 'mon chien', 'pet food',
      'nourriture pour', 'aquarium', 'حيوان',
    ],
    'electronics': [
      'chargeur', 'charger', 'cable', 'usb', 'ecouteur', 'casque',
      'powerbank', 'batterie externe', 'telephone', 'smartphone', 'adaptateur',
      'شاحن',
    ],
    'gifts': [
      // 'present' left out on purpose — too common as an ordinary adjective
      // in FR and EN; 'cadeau' and 'gift' already carry the intent.
      'cadeau', 'cadhiya', 'gift', 'souvenir', 'offrir',
      'هدية',
    ],
    'bakery': [
      'patisserie', 'gateau', 'viennoiserie', 'croissant', 'tarte',
      'mlawi', 'cake', 'pastry', 'anniversaire', 'مخبزة', 'حلويات',
    ],
    'grocery': [
      'course', 'supermarche', 'epicerie', 'lait', 'shampoing', 'detergent',
      'grand surface', 'grocery', 'سوبر ماركت',
    ],
  };

  static String _foldAccents(String s) {
    const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }

  // ── Food vocabulary: concepts → the words the data actually uses ──────────
  //
  // The model emits FREE TEXT in `category`, and the food query turned that
  // straight into `category ilike '%<text>%'` as an AND filter. So a perfectly
  // reasonable word that simply isn't a value in the data emptied the whole
  // search: "fast food" matched 0 of 403 available items, even though
  // Burgers (13), Sandwiches (28), Chapati (34), Malfouf (22) and Makloub
  // (14) are sitting right there. Measured live 2026-10-13.
  //
  // The fix is a map here rather than the real vocabulary in the prompt. Those
  // 59 distinct `food_items.category` values are not a taxonomy — the same
  // thing is spelled three ways (Pizza / Pizzas / Nos Pizza, Sandwich /
  // Sandwiches / Sandwichs, Makloub / Makloubs / Nos Makloubs) next to
  // per-restaurant junk like "VIP" and "The Classic Coffee". Feeding that to
  // the model teaches it noise and costs ~1k tokens on every message of a
  // prompt already around 7.3k. Resolving concepts here is deterministic,
  // free, and testable without a deploy.
  //
  // Values are ilike SUBSTRINGS, so a stem covers the spelling variants:
  // 'sandwich' reaches Sandwich/Sandwiches/Sandwichs/Club sandwich, 'makloub'
  // reaches all three Makloub spellings, 'salad' reaches Salades and Salads.
  // Accents are NOT folded by ilike, so an accented value needs both forms
  // ('pate' will not match 'Pâtes'). No commas, apostrophes, slashes or
  // parentheses: these go into a PostgREST `or=(…)` list, where a comma would
  // split the term and the rest would be parsed as a filter. A test enforces
  // that.
  static const Map<String, List<String>> _kFoodConcepts = {
    // Umbrella concepts — any member is a legitimate answer to the concept.
    'fast food': [
      'burger', 'sandwich', 'chapati', 'makloub', 'malfouf',
      'mlewi', 'mlawi', 'tabouna', 'cornet', 'baguette farcie', 'tacos',
    ],
    'junk food': ['burger', 'sandwich', 'chapati', 'tacos', 'cornet'],
    'makla tounsia': [
      'makloub', 'malfouf', 'mlewi', 'mlawi', 'tabouna', 'chapati',
      'baguette farcie', 'cornet', 'lablabi',
    ],
    'tunisien': [
      'makloub', 'malfouf', 'mlewi', 'mlawi', 'tabouna', 'chapati',
      'baguette farcie', 'cornet', 'lablabi',
    ],
    'leger': ['salad', 'soup', 'entree', 'entrée', 'starter', 'oeuvre'],
    'grillade': ['grill', 'viande', 'volaille', 'poulet'],
    'fruits de mer': ['poisson', 'seafood', 'paella'],
    'petit dejeuner': ['breakfast', 'dejeuner', 'déjeuner', 'boisson chaude'],
    // Spelling and language variants of one thing.
    'pizza': ['pizza'],
    'calzone': ['calzone'],
    'burger': ['burger'],
    'sandwich': ['sandwich', 'baguette farcie', 'club sandwich'],
    'salade': ['salad'],
    'soupe': ['soup'],
    'poisson': ['poisson', 'seafood'],
    'poulet': ['poulet', 'volaille'],
    'viande': ['viande', 'grill'],
    'pates': ['pasta', 'pâtes', 'lasagne', 'gratin'],
    'dessert': ['dessert', 'gaufre'],
    'boisson': ['boisson', 'drink', 'mojito', 'smoothie', 'coffee', 'cafe'],
    'cafe': ['coffee', 'cafe', 'boisson chaude'],
  };

  /// English / Derja / Arabic ways of naming the concepts above. Kept apart
  /// from the map itself so one concept's word list is edited in one place.
  static const Map<String, String> _kFoodConceptAliases = {
    'fastfood': 'fast food',
    'street food': 'fast food',
    'snack': 'fast food',
    'tunisian': 'tunisien',
    'tunisienne': 'tunisien',
    'tounsi': 'tunisien',
    'makla': 'makla tounsia',
    'light': 'leger',
    'healthy': 'leger',
    'sain': 'leger',
    'grill': 'grillade',
    'grille': 'grillade',
    'mechwi': 'grillade',
    'mchwi': 'grillade',
    'seafood': 'fruits de mer',
    'breakfast': 'petit dejeuner',
    'ftour': 'petit dejeuner',
    'pasta': 'pates',
    'salad': 'salade',
    'soup': 'soupe',
    'chicken': 'poulet',
    'meat': 'viande',
    'fish': 'poisson',
    'drink': 'boisson',
    'boissons': 'boisson',
    'coffee': 'cafe',
    'sweet': 'dessert',
    'sucre': 'dessert',
  };

  /// The two maps above, for the integrity tests — a pattern containing a
  /// comma or an alias pointing nowhere is only ever caught by reading them.
  @visibleForTesting
  static Map<String, List<String>> get foodConceptsForTest => _kFoodConcepts;

  @visibleForTesting
  static Map<String, String> get foodConceptAliasesForTest =>
      _kFoodConceptAliases;

  /// Turns the model's free-text food category into the words the catalogue
  /// really uses.
  ///
  /// Returns `[raw]` unchanged when the term isn't a known concept — an
  /// unrecognised word must still be searched, exactly as before, not
  /// dropped. Returns `[]` for null/blank so callers can skip the filter.
  @visibleForTesting
  static List<String> expandFoodConcept(String? raw) {
    final term = raw?.trim() ?? '';
    if (term.isEmpty) return const [];

    // Separators to spaces so "fast-food" and "fast_food" land on "fast food".
    final key = _foldAccents(term)
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (key.isEmpty) return [term];

    final canonical = _kFoodConceptAliases[key] ?? key;
    final hit = _kFoodConcepts[canonical] ??
        // "pizzas" → "pizza", "burgers" → "burger". The model usually emits
        // the singular, but it is not contractually bound to.
        (key.endsWith('s')
            ? _kFoodConcepts[_kFoodConceptAliases[
                    key.substring(0, key.length - 1)] ??
                key.substring(0, key.length - 1)]
            : null);
    return hit ?? [term];
  }

  /// Backward-compatibility fallback (plan risk R5).
  ///
  /// A deployment where the edge function predates `service_category` still
  /// returns `shop_search` with the catalogue only hinted at in prose. Rather
  /// than searching nothing, infer the slug from what the user typed. This
  /// runs ONLY when the server left the field empty — a server-sent slug
  /// always wins, because the model saw the whole conversation and this
  /// doesn't.
  static String? inferServiceCategory(String userText) {
    final t = _foldAccents(userText);
    if (t.trim().isEmpty) return null;
    for (final slug in _kCategoryKeywords.keys) {
      for (final kw in _kCategoryKeywords[slug]!) {
        if (_containsTerm(t, _foldAccents(kw))) return slug;
      }
    }
    return null;
  }

  /// Whole-word match for Latin terms, plain substring for the Arabic ones.
  /// Substring matching alone is too eager here: "lait" would fire on
  /// "laitue", "rose" on "arrosé", "cable" on "cablage" — each of which would
  /// drag a food question into the wrong catalogue.
  static bool _containsTerm(String haystack, String term) {
    final isLatin = RegExp(r'^[a-z0-9 ]+$').hasMatch(term);
    if (!isLatin) return haystack.contains(term);
    // [sx]? so the singular term still matches the French plural:
    // fleur→fleurs, cadeau→cadeaux, course→courses.
    return RegExp('(?<![a-z0-9])${RegExp.escape(term)}[sx]?(?![a-z0-9])')
        .hasMatch(haystack);
  }

  /// Said when the exact request found nothing but the catalogue is not
  /// empty, so the cards shown are the shop's stock rather than matches.
  /// Claims nothing about them beyond where they come from.
  static String relaxedNoticeFor(String? slug) {
    final phrase = _kCategoryWithArticle[slug];
    if (phrase == null) {
      return 'Je n\'ai pas trouvé exactement ça — voici ce qui est disponible.';
    }
    return 'Je n\'ai pas trouvé exactement ça, mais voici ce que '
        '$phrase a en rayon 👇';
  }

  /// Honest empty state. Names the catalogue that was actually searched and
  /// offers the nearest sibling — without claiming the sibling has anything,
  /// and without ever inventing a shop, a product or a price.
  static String noResultsMessageFor(
    String? slug, {
    num? maxPrice,
    num? minPrice,
  }) {
    // When a budget was applied, it is by far the most likely reason the
    // search came back empty — saying "rien de disponible" without naming it
    // reads as "the shop is empty", which is usually false and unhelpful.
    final budget = _budgetPhrase(maxPrice, minPrice);
    final label = _kCategoryLabel[slug];
    if (label == null) {
      return budget == null
          ? _kNoResultsMessage
          : 'Rien trouvé $budget. Essaie avec un budget un peu plus large 🔍';
    }
    if (slug == 'food') {
      return budget == null
          ? 'Je ne trouve rien qui corresponde dans les restaurants ouverts '
              'en ce moment. Essaie un autre plat ou reviens un peu plus tard 🍽️'
          : 'Rien $budget dans les restaurants ouverts en ce moment. '
              'Avec un budget un peu plus large je devrais trouver 🍽️';
    }
    if (budget != null) {
      return 'Rien $budget côté $label pour le moment. '
          'Dis-moi un budget un peu plus large et je regarde à nouveau 💡';
    }
    final neighbour = _kCategoryNeighbour[slug];
    final neighbourLabel = neighbour == null ? null : _kCategoryLabel[neighbour];
    final suffix = neighbourLabel == null
        ? ''
        : ' Je peux regarder côté $neighbourLabel si tu veux.';
    return 'Rien de disponible côté $label pour le moment — '
        'soit la boutique est fermée, soit elle n\'a pas cet article.$suffix';
  }

  /// "sous 40 TND" / "au-dessus de 30 TND" / "entre 20 et 50 TND", or null.
  /// Trailing zeros are trimmed so 40.0 reads as "40", not "40.000".
  static String? _budgetPhrase(num? maxPrice, num? minPrice) {
    String n(num v) => v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toString();
    if (maxPrice != null && minPrice != null) {
      return 'entre ${n(minPrice)} et ${n(maxPrice)} TND';
    }
    if (maxPrice != null) return 'sous ${n(maxPrice)} TND';
    if (minPrice != null) return 'au-dessus de ${n(minPrice)} TND';
    return null;
  }

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

    // R5 — forward/backward compatibility between app build and function
    // build. An edge function that predates `service_category` still emits
    // shop_search, with the catalogue only implied in prose; infer it from the
    // user's own words rather than searching nothing. A slug the server did
    // send always wins — the model saw the whole conversation, this doesn't.
    // When nothing can be inferred we keep 'grocery', which is exactly what
    // this intent searched before the multi-catalogue work.
    final _AiIntent resolved =
        (intent.intentRaw == 'shop_search' && intent.serviceCategory == null)
            ? intent.withServiceCategory(
                inferServiceCategory(userText) ?? 'grocery',
              )
            : intent;

    String finalText = resolved.message;
    List<ProductResult> products = [];
    try {
      switch (resolved.intentRaw) {
        case 'search_food':
          products = await _queryFoodItems(resolved);
          if (products.isEmpty) {
            finalText = noResultsMessageFor('food',
                maxPrice: resolved.maxPrice, minPrice: resolved.minPrice);
          }
          break;
        case 'restaurant_search':
          products = await _queryRestaurants(resolved);
          if (products.isEmpty) finalText = noResultsMessageFor('food');
          break;
        case 'shop_search':
          final shopResult = await _queryShopItems(resolved);
          products = shopResult.items;
          if (products.isEmpty) {
            finalText = noResultsMessageFor(
              resolved.serviceCategory,
              maxPrice: resolved.maxPrice,
              minPrice: resolved.minPrice,
            );
          } else if (shopResult.relaxed) {
            // The cards below are the shop's catalogue, not matches for what
            // was asked. Say so rather than letting the lead-in ("Je regarde
            // côté électronique") imply these are the chargers they wanted.
            finalText =
                '${resolved.message}\n\n${relaxedNoticeFor(resolved.serviceCategory)}';
          }
          break;
        case 'delivery_request':
          finalText = await _appendRecipientHint(resolved.message);
          products = [_buildDeliveryCard()];
          break;
        case 'track_order':
          finalText = await _buildOrderStatusReply(resolved.message);
          break;
        default:
          // 'general' is also where Facture questions land (SYSTEM_PROMPT RULE
          // 2 routes them here — there's no dedicated intent for it, deliberately
          // not building one: see the restaurant_search vs facture/colis
          // investigation). Only touch the message when the raw text actually
          // looks facture-shaped, so off-topic redirects / disambiguation
          // questions / every other 'general' reply is left untouched.
          if (resolved.intentRaw == 'general' &&
              _looksLikeFactureQuestion(userText)) {
            finalText = await _appendBillTypeHint(resolved.message);
            // The explanation used to be text-only, leaving the user to find
            // the Facture section themselves. The card below opens it.
            products = [_buildFactureCard()];
          }
          break;
      }
    } on _QueryFailure catch (e) {
      debugPrint('AiChatService – $e');
      // The catalogue could not be read, so we do not know whether it has
      // matches. Say that, show no cards, and persist nothing: reporting an
      // empty result here is what hid the is_blocked 400 (see _QueryFailure).
      return ChatMessage(text: queryFailedMessage(), isUser: false);
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
      intent: resolved.intentRaw,
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
      // NOT `return []`. An empty list means "the catalogue genuinely has
      // nothing matching", and the caller says exactly that to the user. A
      // failed query means we don't know, and claiming nothing was found
      // hides the bug — that is how the is_blocked 400 above stayed invisible
      // for three weeks. Fail loudly instead; sendMessage shows an error.
      throw _QueryFailure('food', e);
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
      // No blocked-venue filter here, deliberately. This query used to carry
      // `.not('is_blocked', 'is', true)`, written 2026-09-10 against the old
      // `restaurants` TABLE. Migration 20260922010000 replaced that table with
      // a VIEW over `vendors` and — in its own words — "deliberately NOT
      // mirrored" is_blocked, which survives only on `restaurants_legacy`
      // until its phase 2 moves the column onto `vendors`. PostgREST answered
      // every request with 400 "column restaurants.is_blocked does not exist",
      // the catch below turned that into an empty list, and the caller showed
      // it as "nothing found": restaurant search returned zero rows for every
      // query, for three weeks, with no visible error. Dropping the filter
      // also makes this consistent with the rest of the app — no other venue
      // listing in the client filters on it. Re-add it (here and in the other
      // listings) once the column lives on `vendors`.
      var query = _supabase.from('restaurants').select('''
        id, name, description, image_url, rating, review_count,
        delivery_time_min, delivery_fee, is_open, categories
      ''').eq('is_open', true);

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
      // See _queryFoodItems: a failure is not an empty catalogue.
      throw _QueryFailure('restaurant', e);
    }
  }

  // ── Query one shop catalogue ──────────────────────────────────────────────
  // Was `grocery_items`, which is a VIEW hard-filtered to
  // `WHERE vendors.category = 'grocery'` — so bakery, flowers, pets, gifts and
  // electronics items were structurally unreachable no matter what the model
  // asked for. Goes straight to `vendor_items` + `vendors` (the single source
  // of truth, see migration 20260922010000) and filters on the slug instead.
  // For 'grocery' this returns exactly the rows the old view returned.

  /// Runs the catalogue search, relaxing the filters until something comes
  /// back. [relaxed] is true when the rows are the shop's catalogue rather
  /// than matches for what was literally asked — the caller says so instead
  /// of passing them off as exact hits.
  ///
  /// This tiering is not academic. Measured against the live catalogues, the
  /// model's own keyword emptied 3 of 6 shops that had stock: "chargeur"
  /// matched none of the 6 electronics items, "anniversaire"+"gâteau" none of
  /// the 5 bakery items, and for groceries it emitted the two words glued
  /// together ("lait shampoing"), which matches nothing by construction.
  /// Small catalogues plus a free-text keyword is simply a bad combination.
  ///
  /// Price bounds are never relaxed: a budget is the user's own constraint,
  /// not a search hint, and showing over-budget items would be worse than
  /// showing none.
  /// The order filters are given up in, as a list of tiers. Tier 1 asks for
  /// exactly what the model wanted; each later tier drops one layer. Tiers
  /// that would repeat the previous query are never emitted.
  ///
  /// Note what is NOT in this record: price. There is deliberately no knob
  /// for it, so no tier can drop the user's budget — a budget is their own
  /// constraint, and showing over-budget items would be worse than showing
  /// none. [_fetchShopRows] applies the bounds unconditionally.
  @visibleForTesting
  static List<({bool keyword, bool category})> relaxationPlan({
    required bool hasKeyword,
    required bool hasCategory,
  }) =>
      [
        (keyword: hasKeyword, category: hasCategory),
        if (hasKeyword) (keyword: false, category: hasCategory),
        if (hasCategory) (keyword: false, category: false),
      ];

  Future<({List<ProductResult> items, bool relaxed})> _queryShopItems(
    _AiIntent intent,
  ) async {
    final slug = intent.serviceCategory ?? 'grocery';
    final hasKeyword = intent.keyword != null && intent.keyword!.isNotEmpty;
    final hasCategory = intent.category != null && intent.category!.isNotEmpty;

    final attempts = relaxationPlan(
      hasKeyword: hasKeyword,
      hasCategory: hasCategory,
    );

    for (var i = 0; i < attempts.length; i++) {
      final rows = await _fetchShopRows(
        slug,
        intent,
        useKeyword: attempts[i].keyword,
        useCategory: attempts[i].category,
      );
      if (rows.isNotEmpty) return (items: rows, relaxed: i > 0);
    }
    return (items: const <ProductResult>[], relaxed: false);
  }

  Future<List<ProductResult>> _fetchShopRows(
    String slug,
    _AiIntent intent, {
    required bool useKeyword,
    required bool useCategory,
  }) async {
    try {
      var query = _supabase.from('vendor_items').select('''
        id, name, description, price, discount_price, image_url, category,
        vendors!inner (id, name, image_url, rating, is_open, category)
      ''').eq('is_available', true).eq('vendors.category', slug);

      if (intent.maxPrice != null) query = query.lte('price', intent.maxPrice!);
      if (intent.minPrice != null) query = query.gte('price', intent.minPrice!);
      if (useCategory) {
        query = query.ilike('category', '%${intent.category}%');
      }
      if (useKeyword) {
        query = query.or(
          'name.ilike.%${intent.keyword}%,description.ilike.%${intent.keyword}%',
        );
      }

      final rows = await query.order('price', ascending: true).limit(20)
          as List<dynamic>;

      return rows
          // Same reasoning as the restaurant query above — drop closed shops.
          .where((r) =>
              r['vendors'] != null &&
              (r['vendors'] as Map<String, dynamic>)['is_open'] == true)
          .map<ProductResult>((r) {
        final shop = r['vendors'] as Map<String, dynamic>;
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
      // Propagates out of the relaxation loop in _queryShopItems on purpose:
      // a broken query is not a tier that "found nothing", so retrying the
      // next tier would just repeat the same failure and end up reporting an
      // empty shop. See _queryFoodItems.
      throw _QueryFailure('shop', e);
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

  // ── Facture card ──────────────────────────────────────────────────────────
  // Opens the Facture flow. The fee is read from kFlatDeliveryFee — the same
  // constant facture_screen.dart uses — rather than retyped, so the figure
  // the assistant quotes cannot drift from the one the user is charged. It is
  // existing fee logic, not a price this assistant invents.

  ProductResult _buildFactureCard() => ProductResult(
        type: 'facture',
        id: 'facture_payment',
        name: 'Payer une facture',
        description:
            'STEG, SONEDE, Topnet… un livreur collecte le montant et paie '
            'pour vous. Frais de service : '
            '${kFlatDeliveryFee.toStringAsFixed(3)} TND.',
        price: 0.0,
        currency: 'TND',
        imageUrl: null,
        sourceName: 'Amana Facture',
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

/// Thrown by the catalogue queries when the request itself failed — a bad
/// column, a dropped connection, an RLS refusal. Deliberately distinct from
/// "the query ran and matched nothing": the two used to be indistinguishable
/// (every catch returned an empty list), so a hard PostgREST 400 reached the
/// user as "Je ne trouve rien qui corresponde…". Never conflate them again.
class _QueryFailure implements Exception {
  /// Which catalogue was being read — 'food', 'restaurant' or 'shop'.
  final String what;
  final Object cause;
  const _QueryFailure(this.what, this.cause);
  @override
  String toString() => 'QueryFailure($what): $cause';
}

// ── Internal intent model ─────────────────────────────────────────────────────

class _AiIntent {
  final String message;
  final String intentRaw;
  final String? healthGoal;
  /// Which Amana shop catalogue to search — a `vendors.category` slug. Null
  /// when the request isn't a catalogue search, or when an older deployment of
  /// the edge function didn't send the field (see [AiChatService.inferServiceCategory]).
  final String? serviceCategory;
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
    this.serviceCategory,
    this.category,
    this.keyword,
    this.spicy,
    this.vegetarian,
    this.maxPrice,
    this.minPrice,
    this.deliveryTime,
  });

  _AiIntent withServiceCategory(String? slug) => _AiIntent(
        message: message,
        intentRaw: intentRaw,
        healthGoal: healthGoal,
        serviceCategory: slug,
        category: category,
        keyword: keyword,
        spicy: spicy,
        vegetarian: vegetarian,
        maxPrice: maxPrice,
        minPrice: minPrice,
        deliveryTime: deliveryTime,
      );

  /// Builds an intent from the JSON map the `ai-chat` Edge Function returns.
  factory _AiIntent.fromJson(Map<String, dynamic> json) {
    return _AiIntent(
      message: (json['message'] as String?)?.trim().isNotEmpty == true
          ? json['message'] as String
          : 'Comment puis-je vous aider ? 😊',
      intentRaw: (json['intent'] as String?) ?? 'general',
      healthGoal: json['health_goal'] as String?,
      serviceCategory:
          AiChatService.normaliseServiceCategory(json['service_category']),
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