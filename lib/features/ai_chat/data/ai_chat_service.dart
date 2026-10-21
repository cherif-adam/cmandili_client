// lib/features/ai_chat/data/ai_chat_service.dart
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
//
// This file routes a message; the pieces live next to it:
//   chat_function_client.dart    the Edge Function call
//   chat_intent.dart             what it answers, and the failures
//   catalogue_search.dart        dishes, restaurants, shop catalogues
//   account_hints.dart           saved recipient, usual bill, order status
//   chat_cards.dart              the parcel and bill cards
//   chat_history_repository.dart the saved conversation
//   chat_vocabulary.dart         catalogues and food concepts
//   chat_wording.dart            every sentence the app writes itself

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/chat_message.dart';
import 'account_hints.dart';
import 'catalogue_search.dart';
import 'chat_cards.dart';
import 'chat_function_client.dart';
import 'chat_history_repository.dart';
import 'chat_intent.dart';
import 'chat_vocabulary.dart';
import 'chat_wording.dart';

class AiChatService {
  // ── Supabase ──────────────────────────────────────────────────────────────

  final _supabase = Supabase.instance.client;

  late final _function = ChatFunctionClient(_supabase);
  late final _catalogue = CatalogueSearch(_supabase);
  late final _hints = AccountHints(_supabase);
  late final _history = ChatHistoryRepository(_supabase);

  // ── Vocabulary and wording, as the app and the tests know them ────────────
  // Each one is the function of the same name in chat_vocabulary.dart,
  // chat_wording.dart or catalogue_search.dart.

  static String queryFailedMessage({String lang = 'fr'}) =>
      ChatWording.queryFailedMessage(lang: lang);

  static const List<String> kServiceCategories = ChatVocabulary.kServiceCategories;

  static String? normaliseServiceCategory(Object? raw) =>
      ChatVocabulary.normaliseServiceCategory(raw);

  @visibleForTesting
  static Map<String, List<String>> get foodConceptsForTest =>
      ChatVocabulary.foodConceptsForTest;

  @visibleForTesting
  static Map<String, String> get foodConceptAliasesForTest =>
      ChatVocabulary.foodConceptAliasesForTest;

  @visibleForTesting
  static List<String> expandFoodConcept(String? raw) =>
      ChatVocabulary.expandFoodConcept(raw);

  static String? inferServiceCategory(String userText) =>
      ChatVocabulary.inferServiceCategory(userText);

  static const List<String> kLanguages = ChatWording.kLanguages;

  static String normaliseLang(dynamic raw) => ChatWording.normaliseLang(raw);

  static String relaxedNoticeFor(String? slug, {String lang = 'fr'}) =>
      ChatWording.relaxedNoticeFor(slug, lang: lang);

  static String relaxedFoodNotice({String lang = 'fr'}) =>
      ChatWording.relaxedFoodNotice(lang: lang);

  static String relaxedRestaurantNotice({String lang = 'fr'}) =>
      ChatWording.relaxedRestaurantNotice(lang: lang);

  static String noResultsMessageFor(
    String? slug, {
    num? maxPrice,
    num? minPrice,
    String lang = 'fr',
  }) =>
      ChatWording.noResultsMessageFor(slug,
          maxPrice: maxPrice, minPrice: minPrice, lang: lang);

  @visibleForTesting
  static List<ProductResult> restaurantCardsFromItemRows(
    List<Map<String, dynamic>> rows, {
    List<String> matchedTerms = const [],
    String? Function(dynamic)? resolveImage,
    int maxCards = 15,
    int maxHintParts = 3,
  }) =>
      CatalogueSearch.restaurantCardsFromItemRows(rows,
          matchedTerms: matchedTerms,
          resolveImage: resolveImage,
          maxCards: maxCards,
          maxHintParts: maxHintParts);

  @visibleForTesting
  static List<({bool keyword, bool category})> relaxationPlan({
    required bool hasKeyword,
    required bool hasCategory,
  }) =>
      CatalogueSearch.relaxationPlan(hasKeyword: hasKeyword, hasCategory: hasCategory);

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
    final ChatIntent intent;
    try {
      intent = await _function.call(userText, history, imageFile: imageFile);
    } catch (e) {
      debugPrint('AiChatService – ai-chat function error: $e');
      final kind = e is ChatFailure ? e.kind : ChatFailureKind.malformed;
      return ChatMessage(text: ChatWording.errorMessageFor(kind), isUser: false);
    }

    // R5 — forward/backward compatibility between app build and function
    // build. An edge function that predates `service_category` still emits
    // shop_search, with the catalogue only implied in prose; infer it from the
    // user's own words rather than searching nothing. A slug the server did
    // send always wins — the model saw the whole conversation, this doesn't.
    // When nothing can be inferred we keep 'grocery', which is exactly what
    // this intent searched before the multi-catalogue work.
    final ChatIntent resolved =
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
          final foodResult = await _catalogue.queryFoodItems(resolved);
          products = foodResult.items;
          if (products.isEmpty) {
            finalText = noResultsMessageFor('food',
                maxPrice: resolved.maxPrice,
                minPrice: resolved.minPrice,
                lang: resolved.lang);
          } else if (foodResult.relaxed) {
            finalText =
                '${resolved.message}\n\n${relaxedFoodNotice(lang: resolved.lang)}';
          }
          break;
        case 'restaurant_search':
          final venueResult = await _catalogue.queryRestaurants(resolved);
          products = venueResult.items;
          if (products.isEmpty) {
            finalText = noResultsMessageFor('food', lang: resolved.lang);
          } else if (venueResult.relaxed) {
            finalText =
                '${resolved.message}\n\n${relaxedRestaurantNotice(lang: resolved.lang)}';
          }
          break;
        case 'shop_search':
          final shopResult = await _catalogue.queryShopItems(resolved);
          products = shopResult.items;
          if (products.isEmpty) {
            finalText = noResultsMessageFor(
              resolved.serviceCategory,
              maxPrice: resolved.maxPrice,
              minPrice: resolved.minPrice,
              lang: resolved.lang,
            );
          } else if (shopResult.relaxed) {
            // The cards below are the shop's catalogue, not matches for what
            // was asked. Say so rather than letting the lead-in ("Je regarde
            // côté électronique") imply these are the chargers they wanted.
            finalText =
                '${resolved.message}\n\n${relaxedNoticeFor(resolved.serviceCategory, lang: resolved.lang)}';
          }
          break;
        case 'delivery_request':
          finalText = await _hints.appendRecipientHint(resolved.message);
          products = [ChatCards.delivery()];
          break;
        case 'track_order':
          finalText = await _hints.buildOrderStatusReply(resolved.message);
          break;
        default:
          // 'general' is also where Facture questions land (SYSTEM_PROMPT RULE
          // 2 routes them here — there's no dedicated intent for it, deliberately
          // not building one: see the restaurant_search vs facture/colis
          // investigation). Only touch the message when the raw text actually
          // looks facture-shaped, so off-topic redirects / disambiguation
          // questions / every other 'general' reply is left untouched.
          if (resolved.intentRaw == 'general' &&
              _hints.looksLikeFactureQuestion(userText)) {
            finalText = await _hints.appendBillTypeHint(resolved.message);
            // The explanation used to be text-only, leaving the user to find
            // the Facture section themselves. The card below opens it.
            products = [ChatCards.facture()];
          }
          break;
      }
    } on QueryFailure catch (e) {
      debugPrint('AiChatService – $e');
      // The catalogue could not be read, so we do not know whether it has
      // matches. Say that, show no cards, and persist nothing: reporting an
      // empty result here is what hid the is_blocked 400 (see QueryFailure).
      return ChatMessage(text: queryFailedMessage(lang: resolved.lang), isUser: false);
    }

    // Persist AFTER finalText is resolved so history restoration (chat re-open)
    // shows the same order-status text the user actually saw, not just the
    // LLM's bare "Je vérifie ça !" lead-in.
    _history.persistMessages(
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

  // ── Saved conversation and order context ──────────────────────────────────

  /// See [ChatHistoryRepository.loadHistory].
  Future<List<ChatMessage>> loadHistory({int limit = 40}) =>
      _history.loadHistory(limit: limit);

  /// See [ChatHistoryRepository.clearHistory].
  Future<bool> clearHistory() => _history.clearHistory();

  /// See [AccountHints.hasActiveOrder].
  Future<bool> hasActiveOrder() => _hints.hasActiveOrder();
}
