/// What the assistant's free text maps to: the shop catalogues, the food
/// concepts and the words that point at a catalogue.
class ChatVocabulary {
  ChatVocabulary._();

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

  /// Lower case, accents removed — how every lookup here compares words.
  static String foldAccents(String s) {
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
  static Map<String, List<String>> get foodConceptsForTest => _kFoodConcepts;

  static Map<String, String> get foodConceptAliasesForTest =>
      _kFoodConceptAliases;

  /// Turns the model's free-text food category into the words the catalogue
  /// really uses.
  ///
  /// Returns `[raw]` unchanged when the term isn't a known concept — an
  /// unrecognised word must still be searched, exactly as before, not
  /// dropped. Returns `[]` for null/blank so callers can skip the filter.
  static List<String> expandFoodConcept(String? raw) {
    final term = raw?.trim() ?? '';
    if (term.isEmpty) return const [];

    // Separators to spaces so "fast-food" and "fast_food" land on "fast food".
    final key = foldAccents(term)
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
    final t = foldAccents(userText);
    if (t.trim().isEmpty) return null;
    for (final slug in _kCategoryKeywords.keys) {
      for (final kw in _kCategoryKeywords[slug]!) {
        if (_containsTerm(t, foldAccents(kw))) return slug;
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
}
