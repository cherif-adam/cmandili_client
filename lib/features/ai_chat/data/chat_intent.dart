import 'chat_vocabulary.dart';
import 'chat_wording.dart';

// ── Failure classification (distinct error messages, see sendMessage) ────────

enum ChatFailureKind { network, server, malformed }

/// Thrown by [ChatFunctionClient] so sendMessage's catch can show a message
/// specific to what actually went wrong, instead of one generic bubble.
class ChatFailure implements Exception {
  final ChatFailureKind kind;
  final String detail;
  const ChatFailure(this.kind, this.detail);
  @override
  String toString() => 'ChatFailure(${kind.name}): $detail';
}

/// Thrown by the catalogue queries when the request itself failed — a bad
/// column, a dropped connection, an RLS refusal. Deliberately distinct from
/// "the query ran and matched nothing": the two used to be indistinguishable
/// (every catch returned an empty list), so a hard PostgREST 400 reached the
/// user as "Je ne trouve rien qui corresponde…". Never conflate them again.
class QueryFailure implements Exception {
  /// Which catalogue was being read — 'food', 'restaurant' or 'shop'.
  final String what;
  final Object cause;
  const QueryFailure(this.what, this.cause);
  @override
  String toString() => 'QueryFailure($what): $cause';
}

// ── Dishes the function already searched ──────────────────────────────────────

/// One dish the user named, as the `ai-chat` function searched it (fuzzy,
/// open restaurants, available dishes): its rows are `food_items` rows with
/// the embedded `restaurants`, ready for a card. [items] is empty when the
/// dish is not on any open menu — the function's message says so.
class ChatDishResult {
  final String dish;
  final bool found;
  final List<Map<String, dynamic>> items;

  const ChatDishResult({
    required this.dish,
    required this.found,
    required this.items,
  });

  factory ChatDishResult.fromJson(Map<String, dynamic> json) => ChatDishResult(
        dish: (json['dish'] as String?) ?? '',
        found: (json['found'] as bool?) ?? false,
        items: [
          for (final item in (json['items'] as List? ?? const []))
            if (item is Map) Map<String, dynamic>.from(item),
        ],
      );

  /// Null when the function sent no `dish_results` (no dish was named, a
  /// health goal, or a build of the function older than 2026-11-06): the app
  /// then runs its own search.
  static List<ChatDishResult>? listFromJson(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final r in raw)
        if (r is Map) ChatDishResult.fromJson(Map<String, dynamic>.from(r)),
    ];
  }
}

// ── Internal intent model ─────────────────────────────────────────────────────

class ChatIntent {
  final String message;
  final String intentRaw;
  final String? healthGoal;
  /// Which Amana shop catalogue to search — a `vendors.category` slug. Null
  /// when the request isn't a catalogue search, or when an older deployment of
  /// the edge function didn't send the field (see [ChatVocabulary.inferServiceCategory]).
  final String? serviceCategory;
  final String? category;
  final String? keyword;
  final bool? spicy;
  final bool? vegetarian;
  final num? maxPrice;
  final num? minPrice;
  final String? deliveryTime;

  /// The language the model answered in — 'fr' | 'en' | 'ar' | 'tn'. Every
  /// client-side sentence that replaces or extends [message] follows it, so a
  /// Derja or English conversation stops turning French the moment a search
  /// comes back empty. 'fr' when an older function build sends no `lang`.
  final String lang;

  /// The dishes the function searched itself, one entry per dish named. When
  /// present the app shows exactly these rows and runs no search of its own:
  /// nothing unrelated may fill the carousel. See [ChatDishResult.listFromJson].
  final List<ChatDishResult>? dishResults;

  /// 'ok', or 'degraded' when no model answered and the function searched the
  /// user's own words.
  final String status;

  bool get deliveryFast => deliveryTime == 'fast';

  const ChatIntent({
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
    this.lang = 'fr',
    this.dishResults,
    this.status = 'ok',
  });

  ChatIntent withServiceCategory(String? slug) => ChatIntent(
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
        lang: lang,
        dishResults: dishResults,
        status: status,
      );

  /// Builds an intent from the JSON map the `ai-chat` Edge Function returns.
  factory ChatIntent.fromJson(Map<String, dynamic> json) {
    final lang = ChatWording.normaliseLang(json['lang']);
    return ChatIntent(
      message: (json['message'] as String?)?.trim().isNotEmpty == true
          ? json['message'] as String
          : switch (lang) {
              'en' => 'How can I help you? 😊',
              'ar' => 'كيف يمكنني مساعدتك؟ 😊',
              'tn' => 'Chnoua n9der n3awnek bih? 😊',
              _ => 'Comment puis-je vous aider ? 😊',
            },
      lang: lang,
      intentRaw: (json['intent'] as String?) ?? 'general',
      healthGoal: json['health_goal'] as String?,
      serviceCategory:
          ChatVocabulary.normaliseServiceCategory(json['service_category']),
      category: json['category'] as String?,
      keyword: json['keyword'] as String?,
      spicy: json['spicy'] as bool?,
      vegetarian: json['vegetarian'] as bool?,
      maxPrice: json['max_price'] as num?,
      minPrice: json['min_price'] as num?,
      deliveryTime: json['delivery_time'] as String?,
      dishResults: ChatDishResult.listFromJson(json['dish_results']),
      status: (json['status'] as String?) ?? 'ok',
    );
  }
}
