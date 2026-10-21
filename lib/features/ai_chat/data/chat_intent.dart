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
    );
  }
}
