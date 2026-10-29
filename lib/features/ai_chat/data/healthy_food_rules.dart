import 'chat_vocabulary.dart';

/// What "eat light" means for the dish cards. Every word list lives here.
///
/// The menus carry no nutrition data (no calories, no fat, no "grilled"
/// flag): only a name, a category and, for about half the dishes, a
/// description. So a health goal becomes two word lists checked on those
/// three fields:
///
///  * [lightWords]: what the assistant's advice talks about (grilled or
///    roasted, salads, fish, soups, vegetables, legumes, chicken, eggs). A
///    dish needs at least one to be suggested.
///  * [heavyWords]: fried food, street food, fast food, fatty or creamy
///    dishes, desserts, sweet drinks. A dish with one is never suggested for
///    a health goal, unless the user named it themselves.
///
/// Why: on 2026-10-29 "ena naaml fi régime w f sport" got grilled chicken,
/// fish and salads as advice, and Makloub Thon, Malfouf, Tabouna, Calzone
/// and Chapati as cards. The old search ORed poulet/viande/thon over the
/// whole menu and kept the 20 cheapest, which are street food.
///
/// Matching is done on accent-folded, lower-case words. A word ending in `*`
/// matches every word starting with it (`grill*`: grill, grille, grillees,
/// grills). Any other word must be a whole word, so `pane` (pané) does not
/// catch "panettone". Several words ("cordon bleu") must follow each other.
/// Arabic words match inside a word, to get past ال and attached prepositions.
class HealthyFoodRules {
  HealthyFoodRules._();

  /// The health goals that mean "light dishes only". Vegetarian is a filter
  /// of its own (is_vegetarian) and iftar is a meal, not a diet: both keep
  /// the ordinary search.
  static const Set<String> lightGoals = {'diet', 'sport', 'diabetes', 'cholesterol'};

  static const List<String> lightWords = [
    // cooked light
    'grill*', 'mchwi*', 'mechoui*', 'mechwi*', 'roti', 'rotie', 'roties', 'rotis',
    'vapeur', 'papillote',
    // salads, soups, vegetables, legumes
    'salade*', 'salad*', 'soupe*', 'soup*', 'chorba', 'lablabi', 'legume*',
    'crudite*', 'lentille*', 'pois chiche*', 'haricot*',
    // fish and seafood
    'poisson*', 'seafood', 'daurade', 'dorade', 'loup', 'rouget', 'merou',
    'espadon', 'thon', 'saumon', 'sardine*', 'crevette*', 'seiche*', 'poulpe',
    'calamar*',
    // lean meat and eggs
    'poulet', 'volaille*', 'dinde', 'escalope', 'filet', 'brochette*', 'kefta',
    'oeuf*', 'omelette',
    // said on the menu itself
    'healthy', 'light', 'leger', 'legere', 'detox',
  ];

  static const List<String> heavyWords = [
    // street food and stuffed breads
    'makloub*', 'maqloub*', 'mlawi*', 'mlewi*', 'melwi*', 'malfouf*', 'tabouna',
    'chapati*', 'chapatti*', 'calzone*', 'cornet*', 'baguette farcie', 'libanais',
    'kabeb', 'kebab*', 'shawarma', 'chawarma', 'tacos', 'panini*', 'sandwich*',
    'hot dog', 'hotdog*',
    // fast food
    'pizza*', 'burger*', 'hamburger*', 'cheeseburger*', 'nuggets', 'cordon bleu',
    // fried
    'frite*', 'friture*', 'frit', 'frits', 'fritto', 'pane', 'panee', 'panes',
    'panees', 'panure', 'croustillant*', 'brik*', 'fricasse*', 'bambalouni',
    'beignet*', 'kafteji',
    // fatty or creamy
    'merguez', 'salami', 'lasagne*', 'gratin*', 'fondant', 'carbonara',
    // desserts and sweets
    'dessert*', 'gateau*', 'gaufre*', 'crepe*', 'tiramisu', 'cheesecake',
    'chocolat*', 'nutella', 'glace*', 'cake', 'cookie*', 'donut*', 'patisserie*',
    'baklawa', 'makroudh', 'zlabia',
    // sweet drinks
    'boisson*', 'drinks', 'soda*', 'coca', 'pepsi', 'fanta', 'mojito*',
    'milkshake*', 'smoothie*', 'jus',
  ];

  /// What the database is asked for: raw substrings (with their accents,
  /// `ilike` does not fold them) covering every light word, matched on the
  /// name, the category and the description. The folded rules above decide.
  static const List<String> serverStems = [
    'grill', 'mchwi', 'mechou', 'méchou', 'mechwi', 'rôti', 'roti', 'vapeur',
    'papillote', 'salad', 'soup', 'chorba', 'lablabi', 'légume', 'legume',
    'crudit', 'lentille', 'pois chiche', 'haricot', 'poisson', 'seafood',
    'daurade', 'dorade', 'loup', 'rouget', 'mérou', 'merou', 'espadon', 'thon',
    'saumon', 'sardine', 'crevette', 'seiche', 'poulpe', 'calamar', 'poulet',
    'volaille', 'dinde', 'escalope', 'filet', 'brochette', 'kefta', 'oeuf',
    'œuf', 'omelette', 'healthy', 'light', 'léger', 'leger', 'légère', 'detox',
  ];

  /// The words that tell a goal in the user's own message, in Derja, French,
  /// English and Arabic. A safety net for the model's health_goal, and what
  /// carries a goal into "a5tarli haja behya" two turns later.
  static const Map<String, List<String>> goalWords = {
    'diet': [
      'regime', 'rejim', 'rejime', 'rijim', 'diet', 'diete', 'dieta', 'maigrir',
      'mincir', 'minceur', 'healthy', 'sain', 'saine', 'sainement', 'light',
      'leger', 'legere', 'calorie*', 'kcal', 'perdre du poids', 'perte de poids',
      'lose weight', 'weight loss', 'low fat', 'nkhass*', 'n5ass*',
      'حمية', 'رجيم', 'ريجيم', 'دايت', 'تخسيس', 'سعرات', 'نظام غذائي',
      'انقاص الوزن', 'إنقاص الوزن', 'خسارة الوزن', 'اكل صحي', 'أكل صحي',
      'طعام صحي', 'وجبة صحية',
    ],
    'sport': [
      'sport', 'sports', 'sportif', 'sportive', 'musculation', 'muscu', 'muscle*',
      'gym', 'fitness', 'crossfit', 'bodybuilding', 'proteine*', 'protein*',
      'workout', 'entrainement', 'training',
      'رياضة', 'رياضي', 'بروتين', 'عضلات', 'كمال الاجسام', 'كمال الأجسام',
    ],
    'diabetes': [
      'diabete*', 'diabetique*', 'diabetes', 'diabetic', 'glycemie', 'insuline',
      'سكري',
    ],
    'cholesterol': [
      'cholesterol*',
      'كوليسترول', 'كولسترول',
    ],
  };

  /// What each goal puts first, among the light dishes.
  static const Map<String, List<String>> goalBonusWords = {
    'diet': ['salade*', 'salad*', 'soupe*', 'soup*', 'legume*', 'grill*', 'mchwi*', 'vapeur'],
    'sport': [
      'poulet', 'dinde', 'escalope', 'filet', 'kefta', 'brochette*', 'thon',
      'poisson*', 'daurade', 'loup', 'rouget', 'espadon', 'crevette*', 'oeuf*',
      'omelette', 'lentille*', 'pois chiche*',
    ],
    'diabetes': ['legume*', 'salade*', 'salad*', 'poisson*', 'grill*'],
    'cholesterol': ['poisson*', 'salade*', 'salad*', 'legume*', 'grill*'],
  };

  // ── Matching ─────────────────────────────────────────────────────────────

  static final RegExp _nonWord = RegExp(r'[^a-z0-9؀-ۿ]+');
  static final RegExp _arabic = RegExp(r'[؀-ۿ]');

  /// Accent-folded, lower-case words of [text] ("Œuf" is "oeuf").
  static List<String> words(String? text) => text == null
      ? const []
      : ChatVocabulary.foldAccents(text)
          .replaceAll('œ', 'oe')
          .replaceAll('æ', 'ae')
          .split(_nonWord)
          .where((w) => w.isNotEmpty)
          .toList();

  /// [word] without its French plural and feminine endings, so the model's
  /// "grillé" finds "Grillée" and "salades" finds "Salade".
  static String _stem(String word) {
    final s = word.replaceAll(RegExp(r'(es|e|s)+$'), '');
    return s.length >= 3 ? s : word;
  }

  /// Whether the rule [rule] is in [tokens] (see the class comment).
  static bool hasWord(List<String> tokens, String rule) {
    if (_arabic.hasMatch(rule)) {
      final parts = rule.split(' ');
      if (parts.length == 1) return tokens.any((t) => t.contains(rule));
      return tokens.join(' ').contains(rule);
    }
    final parts = rule.split(' ');
    for (var i = 0; i + parts.length <= tokens.length; i++) {
      var all = true;
      for (var j = 0; j < parts.length && all; j++) {
        all = _wordMatches(tokens[i + j], parts[j]);
      }
      if (all) return true;
    }
    return false;
  }

  static bool _wordMatches(String token, String rule) => rule.endsWith('*')
      ? token.startsWith(rule.substring(0, rule.length - 1))
      : token == rule;

  static List<String> _hits(List<String> tokens, List<String> rules) =>
      [for (final r in rules) if (hasWord(tokens, r)) r];

  // ── The goal ─────────────────────────────────────────────────────────────

  /// The light goals named in [text].
  static Set<String> goalsInText(String? text) {
    final tokens = words(text);
    return {
      for (final e in goalWords.entries)
        if (e.value.any((w) => hasWord(tokens, w))) e.key,
    };
  }

  /// The heavy words the user asked for in [text] themselves: those dishes
  /// stay allowed ("w chapati?" in the middle of a diet is a question about
  /// chapati).
  static Set<String> heavyAskedFor(String? text) =>
      _hits(words(text), heavyWords).toSet();

  /// The light goals of this search, or an empty set for the ordinary search.
  ///
  /// In order: the model's [modelGoal] when it is a light one; a non-light
  /// goal from the model (vegetarian, iftar) keeps its own search; the user's
  /// own words this turn; then the last few user messages ([earlierUserTexts],
  /// oldest first), unless this turn names a heavy dish ("nheb pizza" after a
  /// diet is a request for pizza, and gets pizza).
  static Set<String> lightGoalsFor({
    String? modelGoal,
    required String userText,
    List<String> earlierUserTexts = const [],
    String? keyword,
    String? category,
  }) {
    if (modelGoal != null) {
      return lightGoals.contains(modelGoal) ? {modelGoal} : const {};
    }
    final now = goalsInText(userText);
    if (now.isNotEmpty) return now;
    if (heavyAskedFor('$userText ${keyword ?? ''} ${category ?? ''}').isNotEmpty) {
      return const {};
    }
    final recent = earlierUserTexts.length > 4
        ? earlierUserTexts.sublist(earlierUserTexts.length - 4)
        : earlierUserTexts;
    return {for (final t in recent) ...goalsInText(t)};
  }

  // ── The dishes ───────────────────────────────────────────────────────────

  /// The light dishes among [rows] (food_items rows: name, category,
  /// description, price, discount_price), best first, at most [max].
  ///
  /// A row is dropped when it has a heavy word the user did not ask for
  /// ([askedFor]: their message plus the model's keyword and category), or
  /// no light word at all. The rest is ranked by the words of [preferred]
  /// (the model's keyword, "poulet grillé" puts grilled chicken first), then
  /// by what the [goals] favour (proteins for sport, salads and soups for a
  /// diet), then by price.
  static List<Map<String, dynamic>> pickLightDishes(
    List<Map<String, dynamic>> rows, {
    required Set<String> goals,
    String? preferred,
    String? askedFor,
    int max = 20,
  }) {
    final allowed = heavyAskedFor(askedFor);
    final preferredWords = words(preferred)
        .where((w) => w.length >= 3 && !_genericWords.contains(w))
        .map(_stem)
        .toSet();
    final bonus = {for (final g in goals) ...?goalBonusWords[g]};

    final scored = <({Map<String, dynamic> row, int score, double price})>[];
    for (final row in rows) {
      final tokens = words('${row['name'] ?? ''} ${row['category'] ?? ''} ${row['description'] ?? ''}');
      // The dish the user asked for stays, whatever else it is ("Chapati
      // Poulet" is filed under Sandwiches, and they asked for a chapati).
      final asked = allowed.where((w) => hasWord(tokens, w)).length;
      if (asked == 0 && _hits(tokens, heavyWords).isNotEmpty) continue;
      final light = _hits(tokens, lightWords).length + asked;
      if (light == 0) continue;
      final nameStems = words('${row['name'] ?? ''}').map(_stem).toSet();
      final score = 100 * preferredWords.where(nameStems.contains).length +
          10 * bonus.where((w) => hasWord(tokens, w)).length +
          light;
      final price = ((row['discount_price'] ?? row['price']) as num?)?.toDouble() ?? 0;
      scored.add((row: row, score: score, price: price));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byPrice = a.price.compareTo(b.price);
      if (byPrice != 0) return byPrice;
      return '${a.row['name']}'.compareTo('${b.row['name']}');
    });
    return [for (final s in scored.take(max)) s.row];
  }

  /// Words of a keyword that say nothing about the dish itself.
  static const Set<String> _genericWords = {
    'plat', 'plats', 'dish', 'dishes', 'repas', 'meal', 'healthy', 'light',
    'leger', 'legere', 'sain', 'saine', 'diet', 'regime', 'proteine',
    'proteines', 'protein', 'avec', 'sans', 'les', 'des', 'aux',
  };
}
