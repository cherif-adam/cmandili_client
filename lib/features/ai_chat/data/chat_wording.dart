import 'chat_intent.dart';

/// Every sentence the app writes itself instead of (or after) the model's:
/// empty results, relaxed results, an unreachable catalogue, a function
/// that never answered. In the language the model answered in.
class ChatWording {
  ChatWording._();

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
  ///
  /// This one DOES get a language: the function answered successfully and said
  /// which language it used, and only the database read afterwards failed.
  /// (Contrast [errorMessageFor], where the function itself never answered.)
  static String queryFailedMessage({String lang = 'fr'}) =>
      switch (normaliseLang(lang)) {
        'en' => 'I could not reach the catalogue — please try again in a '
            'moment 🔧',
        'ar' => 'لم أتمكن من الوصول إلى الكتالوج — يُرجى المحاولة بعد لحظات 🔧',
        'tn' => 'Ma najjemtech nothel lel catalogue — 3awed ba3d chwaya 🔧',
        _ => _kQueryFailedMessage,
      };

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

  // ── Language of the client-side messages ──────────────────────────────────
  //
  // Everything below REPLACES the model's own sentence (empty result, relaxed
  // result, unreachable catalogue), and all of it used to be French — so a
  // user writing in Derja, English or Arabic got a French sentence as soon as
  // a search came back empty. The edge function now reports the language it
  // answered in as `lang`, and these follow it. Tone, fixed per language and
  // not to be mixed (the prompt carries the same rules):
  //   fr → "vous", always. Polite, professional, short sentences.
  //   en → polite and neutral.
  //   ar → polite Modern Standard Arabic.
  //   tn → Derja in Latin script: friendly, simple, warm, never stiff.
  // French loanwords are normal in Derja ("restaurant", "patisserie") and are
  // kept: that is how people write it.
  static const List<String> kLanguages = ['fr', 'en', 'ar', 'tn'];

  /// The language to speak. Falls back to French — the app's default locale —
  /// for anything unknown, including an older function build that sends no
  /// `lang` at all.
  static String normaliseLang(dynamic raw) {
    if (raw is! String) return 'fr';
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return 'fr';
    if (kLanguages.contains(t)) return t;
    // Tolerate the obvious spellings rather than silently falling back.
    return switch (t) {
      'fra' || 'fre' || 'french' || 'francais' || 'français' => 'fr',
      'eng' || 'english' => 'en',
      'ara' || 'arabic' || 'arabe' || 'fusha' => 'ar',
      'tun' || 'tn_ar' || 'derja' || 'darija' || 'tunisian' => 'tn',
      _ => 'fr',
    };
  }

  /// Shop labels per language, for the messages that name what was searched.
  static const Map<String, Map<String, String>> _kCategoryLabelByLang = {
    'fr': _kCategoryLabel,
    'en': {
      'food': 'restaurant',
      'grocery': 'supermarket',
      'bakery': 'bakery',
      'flowers': 'florist',
      'pets': 'pet shop',
      'gifts': 'gift shop',
      'electronics': 'electronics shop',
    },
    'ar': {
      'food': 'المطاعم',
      'grocery': 'المتجر',
      'bakery': 'محل الحلويات',
      'flowers': 'محل الزهور',
      'pets': 'محل الحيوانات',
      'gifts': 'محل الهدايا',
      'electronics': 'محل الإلكترونيات',
    },
    'tn': {
      'food': 'restaurant',
      'grocery': 'supermarché',
      'bakery': 'patisserie',
      'flowers': 'fleuriste',
      'pets': 'animalerie',
      'gifts': 'magasin cadeaux',
      'electronics': 'magasin electronique',
    },
  };

  static String? _labelFor(String? slug, String lang) =>
      (_kCategoryLabelByLang[lang] ?? _kCategoryLabel)[slug];

  /// Said when the exact request found nothing but the catalogue is not
  /// empty, so the cards shown are the shop's stock rather than matches.
  /// Claims nothing about them beyond where they come from.
  static String relaxedNoticeFor(String? slug, {String lang = 'fr'}) {
    final l = normaliseLang(lang);
    if (l == 'fr') {
      // French keeps its article-aware phrasing ("le fleuriste", not "la").
      final phrase = _kCategoryWithArticle[slug];
      return phrase == null
          ? 'Je n\'ai pas trouvé exactement ça — voici ce qui est disponible.'
          : 'Je n\'ai pas trouvé exactement ça, mais voici ce que '
              '$phrase a en rayon 👇';
    }
    final label = _labelFor(slug, l);
    return switch (l) {
      'en' => label == null
          ? 'I could not find exactly that — here is what is available.'
          : 'I could not find exactly that, but here is what the $label '
              'has in stock 👇',
      'ar' => label == null
          ? 'لم أجد ذلك بالتحديد — إليك ما هو متوفر.'
          : 'لم أجد ذلك بالتحديد، لكن إليك ما يتوفر في $label 👇',
      _ => label == null
          ? 'Ma lqitech el7aja bel exact — hani njiblek chnoua famma.'
          : 'Ma lqitech el7aja bel exact, ama hani njiblek chnoua famma '
              'fel $label 👇',
    };
  }

  /// Said when the dish search had to give up a filter: the cards are what is
  /// available now, not matches for what was asked. Same contract as
  /// [relaxedNoticeFor] on the shop side — claim nothing about them beyond
  /// where they come from, and never name a dish, venue or price.
  static String relaxedFoodNotice({String lang = 'fr'}) =>
      switch (normaliseLang(lang)) {
        'en' => 'I could not find exactly that — here is what the open '
            'restaurants have right now 👇',
        'ar' => 'لم أجد ذلك بالتحديد — إليك ما تقدمه المطاعم المفتوحة الآن 👇',
        'tn' => 'Ma lqitech el7aja bel exact — hani njiblek chnoua famma tw '
            '3and el restaurants el mftou7in 👇',
        _ => 'Je n\'ai pas trouvé exactement ça — voici ce qui est disponible '
            'en ce moment dans les restaurants ouverts 👇',
      };

  /// Same, for a venue search.
  static String relaxedRestaurantNotice({String lang = 'fr'}) =>
      switch (normaliseLang(lang)) {
        'en' => 'I could not find exactly that — here are the restaurants '
            'open right now 👇',
        'ar' => 'لم أجد ذلك بالتحديد — إليك المطاعم المفتوحة الآن 👇',
        'tn' => 'Ma lqitech el7aja bel exact — hani njiblek el restaurants '
            'el mftou7in tw 👇',
        _ => 'Je n\'ai pas trouvé exactement ça — voici les restaurants '
            'ouverts en ce moment 👇',
      };

  /// Honest empty state. Names the catalogue that was actually searched and
  /// offers the nearest sibling — without claiming the sibling has anything,
  /// and without ever inventing a shop, a product or a price.
  static String noResultsMessageFor(
    String? slug, {
    num? maxPrice,
    num? minPrice,
    String lang = 'fr',
  }) {
    final l = normaliseLang(lang);
    // When a budget was applied, it is by far the most likely reason the
    // search came back empty — saying "rien de disponible" without naming it
    // reads as "the shop is empty", which is usually false and unhelpful.
    final budget = _budgetPhrase(maxPrice, minPrice, l);
    final label = _labelFor(slug, l);

    if (label == null) {
      if (budget == null) return _genericNoResults(l);
      return switch (l) {
        'en' => 'Nothing found $budget. Please try a slightly wider budget 🔍',
        'ar' => 'لم أجد شيئًا $budget. يُرجى تجربة ميزانية أوسع قليلًا 🔍',
        'tn' => 'Ma famma chay $budget. Jarreb budget chwaya akbar 🔍',
        _ => 'Rien trouvé $budget. Essayez avec un budget un peu plus large 🔍',
      };
    }

    if (slug == 'food') {
      if (budget == null) {
        return switch (l) {
          'en' => 'I cannot find anything matching in the restaurants open '
              'right now. Please try another dish, or come back a little '
              'later 🍽️',
          'ar' => 'لا أجد ما يطابق طلبك في المطاعم المفتوحة حاليًا. '
              'يُرجى تجربة طبق آخر أو العودة لاحقًا 🍽️',
          'tn' => 'Ma lqitech chay ki heka fel restaurants el mftou7in tw. '
              'Jarreb makla okhra wella erja3 ba3d chwaya 🍽️',
          _ => 'Je ne trouve rien qui corresponde dans les restaurants '
              'ouverts en ce moment. Essayez un autre plat ou revenez un peu '
              'plus tard 🍽️',
        };
      }
      return switch (l) {
        'en' => 'Nothing $budget in the restaurants open right now. '
            'A slightly wider budget should find something 🍽️',
        'ar' => 'لا شيء $budget في المطاعم المفتوحة حاليًا. '
            'ميزانية أوسع قليلًا ستجد شيئًا 🍽️',
        'tn' => 'Ma famma chay $budget fel restaurants el mftou7in tw. '
            'B budget chwaya akbar nelqa 🍽️',
        _ => 'Rien $budget dans les restaurants ouverts en ce moment. '
            'Avec un budget un peu plus large je devrais trouver 🍽️',
      };
    }

    if (budget != null) {
      return switch (l) {
        'en' => 'Nothing $budget at the $label for the moment. Tell me a '
            'slightly wider budget and I will look again 💡',
        'ar' => 'لا شيء $budget في $label حاليًا. أخبرني بميزانية أوسع '
            'قليلًا وسأبحث مرة أخرى 💡',
        'tn' => 'Ma famma chay $budget fel $label tw. 9olli budget chwaya '
            'akbar w nchouf 3awed 💡',
        _ => 'Rien $budget côté $label pour le moment. Dites-moi un budget '
            'un peu plus large et je regarde à nouveau 💡',
      };
    }

    final neighbour = _kCategoryNeighbour[slug];
    final neighbourLabel = neighbour == null ? null : _labelFor(neighbour, l);
    return switch (l) {
      'en' => 'Nothing available at the $label for the moment — either the '
          'shop is closed, or it does not carry that item.'
          '${neighbourLabel == null ? '' : ' I can look at the '
              '$neighbourLabel if you would like.'}',
      'ar' => 'لا يتوفر شيء في $label حاليًا — إما أن المحل مغلق أو أنه لا '
          'يوفر هذه السلعة.'
          '${neighbourLabel == null ? '' : ' يمكنني البحث في $neighbourLabel '
              'إن أردت.'}',
      'tn' => 'Ma famma chay fel $label tw — wella el 7anout m3alla9, wella '
          'ma3andhomch el 7aja hedhi.'
          '${neighbourLabel == null ? '' : ' Nchouf lek fel $neighbourLabel '
              'kén t7eb.'}',
      _ => 'Rien de disponible côté $label pour le moment — soit la boutique '
          'est fermée, soit elle n\'a pas cet article.'
          '${neighbourLabel == null ? '' : ' Je peux regarder côté '
              '$neighbourLabel si vous voulez.'}',
    };
  }

  static String _genericNoResults(String lang) => switch (lang) {
        'en' => 'No results for that search — please try something else 🔍',
        'ar' => 'لا توجد نتائج لهذا البحث — يُرجى تجربة شيء آخر 🔍',
        'tn' => 'Ma famma chay fel ba7th hedha — jarreb 7aja okhra 🔍',
        _ => _kNoResultsMessage,
      };

  /// "sous 40 TND" / "au-dessus de 30 TND" / "entre 20 et 50 TND", or null.
  /// Trailing zeros are trimmed so 40.0 reads as "40", not "40.000".
  static String? _budgetPhrase(num? maxPrice, num? minPrice, String lang) {
    String n(num v) => v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toString();
    if (maxPrice == null && minPrice == null) return null;
    final isRange = maxPrice != null && minPrice != null;
    return switch (lang) {
      'en' => isRange
          ? 'between ${n(minPrice)} and ${n(maxPrice)} TND'
          : maxPrice != null
              ? 'under ${n(maxPrice)} TND'
              : 'above ${n(minPrice!)} TND',
      'ar' => isRange
          ? 'بين ${n(minPrice)} و${n(maxPrice)} دينار'
          : maxPrice != null
              ? 'بأقل من ${n(maxPrice)} دينار'
              : 'بأكثر من ${n(minPrice!)} دينار',
      'tn' => isRange
          ? 'bin ${n(minPrice)} w ${n(maxPrice)} TND'
          : maxPrice != null
              ? 'taht ${n(maxPrice)} TND'
              : 'akthar mn ${n(minPrice!)} TND',
      _ => isRange
          ? 'entre ${n(minPrice)} et ${n(maxPrice)} TND'
          : maxPrice != null
              ? 'sous ${n(maxPrice)} TND'
              : 'au-dessus de ${n(minPrice!)} TND',
    };
  }

  // ── Error messages by failure kind ────────────────────────────────────────
  // Previously a single generic bubble regardless of cause. Distinguishes the
  // 3 things that can actually go wrong (see ChatFailureKind / ChatFunctionClient).
  // These three stay French, deliberately, and are the only client-side
  // messages that do. They fire when the edge function never answered at all
  // — no reply means no detected language, and guessing one from the user's
  // raw text here would be a second, worse language detector sitting next to
  // the real one. French is the app's default locale. Every message that CAN
  // know the language does (see queryFailedMessage / noResultsMessageFor).
  static String errorMessageFor(ChatFailureKind kind) => switch (kind) {
        ChatFailureKind.network =>
          'Pas de connexion internet — vérifiez votre réseau et réessayez 📡',
        ChatFailureKind.server =>
          "Notre assistant est momentanément indisponible — réessayez dans un instant 🔧",
        ChatFailureKind.malformed =>
          'Réponse inattendue de notre serveur — réessayez 🔁',
      };
}
