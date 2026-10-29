import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat_message.dart';
import 'chat_intent.dart';
import 'chat_vocabulary.dart';
import 'healthy_food_rules.dart';

/// The three catalogue searches (dishes, restaurants, one shop catalogue),
/// each relaxing its filters tier by tier until something comes back, and
/// the cards they produce. A failed query throws a [QueryFailure]: it is
/// never reported as an empty catalogue.
class CatalogueSearch {
  CatalogueSearch(this._supabase);

  final SupabaseClient _supabase;

  static const String _storageBase =
      'https://hoqlxxtphskgxktqjpfu.supabase.co/storage/v1/object/public/';


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

  /// Dish search, tiered like the shop search.
  ///
  /// Tier 1 asks for exactly what the model wanted; each later tier drops one
  /// layer of PREFERENCE (the keyword, then the category). What no tier may
  /// drop: the budget, the vegetarian flag and the spicy flag. A budget is the
  /// user's own constraint and over-budget cards are worse than none;
  /// `vegetarian` is a dietary requirement, not a hint, and showing a
  /// vegetarian meat dishes to fill the screen would be a bug, not a
  /// relaxation. [relaxed] is true when the cards are the nearest thing
  /// available rather than matches — the caller says so out loud.
  Future<({List<ProductResult> items, bool relaxed})> queryFoodItems(
    ChatIntent intent,
  ) async {
    final patterns = ChatVocabulary.expandFoodConcept(intent.category);
    // The health-goal terms ride the keyword layer: they are a widening of
    // what to look for, so a tier that drops the keyword drops them too.
    final hasKeyword = (intent.keyword?.isNotEmpty ?? false) ||
        _healthGoalKeyword(intent.healthGoal) != null;

    final attempts = relaxationPlan(
      hasKeyword: hasKeyword,
      hasCategory: patterns.isNotEmpty,
    );

    for (var i = 0; i < attempts.length; i++) {
      final rows = await _fetchFoodRows(
        intent,
        patterns,
        useKeyword: attempts[i].keyword,
        useCategory: attempts[i].category,
      );
      if (rows.isNotEmpty) return (items: rows, relaxed: i > 0);
    }
    return (items: const <ProductResult>[], relaxed: false);
  }

  Future<List<ProductResult>> _fetchFoodRows(
    ChatIntent intent,
    List<String> conceptPatterns, {
    required bool useKeyword,
    required bool useCategory,
  }) async {
    try {
      // `restaurants!inner` + the embedded is_open filter, NOT a post-filter
      // in Dart. The closed-venue check used to run here after `.limit(20)`
      // had already been applied server-side, so the 20 cheapest matching
      // dishes were picked across open AND closed restaurants and only then
      // thinned — a search could come back empty while open restaurants held
      // matching dishes. Invisible today (all 12 restaurants are open) and
      // guaranteed to bite the first evening a few close. With the tiers above
      // it got worse than that: an all-closed page of rows would look like
      // "this tier found nothing" and relax a search that had in fact matched.
      var query = _supabase.from('food_items').select('''
        id, name, description, price, discount_price, image_url,
        category, is_spicy, is_vegetarian, preparation_time, restaurant_id,
        restaurants!inner (id, name, image_url, rating, delivery_time_min, delivery_fee, is_open)
      ''').eq('is_available', true).eq('restaurants.is_open', true);

      if (intent.spicy == true) query = query.eq('is_spicy', true);
      // Force vegetarian filter for vegetarian health goal or explicit flag
      if (intent.vegetarian == true || intent.healthGoal == 'vegetarian') {
        query = query.eq('is_vegetarian', true);
      }
      if (intent.maxPrice != null) query = query.lte('price', intent.maxPrice!);
      if (intent.minPrice != null) query = query.gte('price', intent.minPrice!);
      if (intent.deliveryFast) query = query.lte('preparation_time', 20);
      if (useCategory && conceptPatterns.isNotEmpty) {
        // One OR over the concept's real words instead of one ilike on the
        // model's free text. "fast food" matched 0 of 403 items as a literal;
        // its stems match 124. Each pattern is tried against `category` AND
        // `name`, because a concept member is sometimes a dish name rather
        // than a category ('tacos' is no category here, it is a dish).
        query = query.or(conceptPatterns
            .map((p) => 'category.ilike.%$p%,name.ilike.%$p%')
            .join(','));
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

      if (useKeyword) {
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
      }
      if (keywordParts.isNotEmpty) {
        query = query.or(keywordParts.join(','));
      }

      final rows = await query.order('price', ascending: true).limit(20)
          as List<dynamic>;

      return rows
          // The embedded `restaurants.is_open` filter above already guarantees
          // this; the null guard stays because a left-embed shape change would
          // otherwise crash the cast below rather than drop a row.
          .where((r) => r['restaurants'] != null)
          .map<ProductResult>(_foodCard)
          .toList();
    } catch (e) {
      debugPrint('AiChatService – food query error: $e');
      // NOT `return []`. An empty list means "the catalogue genuinely has
      // nothing matching", and the caller says exactly that to the user. A
      // failed query means we don't know, and claiming nothing was found
      // hides the bug — that is how the is_blocked 400 above stayed invisible
      // for three weeks. Fail loudly instead; sendMessage shows an error.
      throw QueryFailure('food', e);
    }
  }

  ProductResult _foodCard(dynamic r) {
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
  }

  // ── Light dishes (diet, sport, diabetes, cholesterol) ─────────────────────

  /// The dishes for a health goal: light ones only, best first.
  ///
  /// The database is asked for every dish with a light word in its name,
  /// category or description, under the user's own hard filters (budget,
  /// vegetarian, spicy, fast). [HealthyFoodRules.pickLightDishes] then drops
  /// the heavy ones the user did not ask for and ranks the rest. There is no
  /// relaxation tier: an empty result is said as such, because showing
  /// makloub under advice about grilled chicken is exactly the bug this
  /// replaces (see [HealthyFoodRules]).
  Future<List<ProductResult>> queryLightFood(
    ChatIntent intent, {
    required Set<String> goals,
    required String userText,
  }) async {
    final List<dynamic> rows;
    try {
      var query = _supabase.from('food_items').select('''
        id, name, description, price, discount_price, image_url,
        category, is_spicy, is_vegetarian, preparation_time, restaurant_id,
        restaurants!inner (id, name, image_url, rating, delivery_time_min, delivery_fee, is_open)
      ''').eq('is_available', true).eq('restaurants.is_open', true);

      if (intent.spicy == true) query = query.eq('is_spicy', true);
      if (intent.vegetarian == true) query = query.eq('is_vegetarian', true);
      if (intent.maxPrice != null) query = query.lte('price', intent.maxPrice!);
      if (intent.minPrice != null) query = query.gte('price', intent.minPrice!);
      if (intent.deliveryFast) query = query.lte('preparation_time', 20);
      query = query.or(HealthyFoodRules.serverStems
          .map((s) => 'name.ilike.%$s%,category.ilike.%$s%,description.ilike.%$s%')
          .join(','));

      rows = await query.order('price', ascending: true).limit(300) as List<dynamic>;
    } catch (e) {
      debugPrint('AiChatService – light food query error: $e');
      throw QueryFailure('food', e);
    }

    final asked = '${intent.keyword ?? ''} ${intent.category ?? ''}';
    return HealthyFoodRules.pickLightDishes(
      rows
          .cast<Map<String, dynamic>>()
          .where((r) => r['restaurants'] != null)
          .toList(),
      goals: goals,
      preferred: asked,
      askedFor: '$userText $asked',
    ).map<ProductResult>(_foodCard).toList();
  }

  // ── Query restaurants (restaurant_search intent) ──────────────────────────
  // A VENUE list, not a dish list. Before this, "best restaurant" / "resto près
  // de moi" had no code path at all — it fell through to search_food and came
  // back as individual dish cards, which is what it looked like it was doing
  // wrong. `restaurants` is publicly readable (RLS: SELECT USING true), so this
  // is a plain client read like the food/shop queries.
  /// Venue search, tiered, matching on WHAT A RESTAURANT SELLS.
  ///
  /// It used to match the concept against the venue's `name` and its
  /// `categories` tag array only. Both are nearly useless here: 11 of 12 rows
  /// have an empty `categories`, and a name match is an accident of branding —
  /// "fast food" reached no venue at all, while 9 open restaurants sell
  /// burgers, sandwiches, chapati or makloub. So the question asked is now
  /// "which open restaurant has an available item matching this concept",
  /// which is what a user means by a venue type.
  ///
  /// Measured live 2026-10-13: "pizzeria" goes from 2 venues (the two with
  /// "pizza" in their name) to 6 — Piccolo Mondo and Titanic food sell 8 pizzas
  /// each and were invisible. "fast food" goes from 0 to 9.
  Future<({List<ProductResult> items, bool relaxed})> queryRestaurants(
    ChatIntent intent,
  ) async {
    final patterns = ChatVocabulary.expandFoodConcept(intent.category);
    final hasKeyword = intent.keyword?.trim().isNotEmpty ?? false;

    final attempts = relaxationPlan(
      hasKeyword: hasKeyword,
      hasCategory: patterns.isNotEmpty,
    );

    for (var i = 0; i < attempts.length; i++) {
      final useKeyword = attempts[i].keyword;
      final useCategory = attempts[i].category;
      // The widest tier has no concept and no keyword left to match items on,
      // so there is nothing to look up in the menus: fall back to the venue
      // list itself, best-rated first.
      final rows = (!useKeyword && !useCategory)
          ? await _fetchOpenRestaurants()
          : await _fetchRestaurantsSelling(
              intent,
              patterns,
              useKeyword: useKeyword,
              useCategory: useCategory,
            );
      if (rows.isNotEmpty) return (items: rows, relaxed: i > 0);
    }
    return (items: const <ProductResult>[], relaxed: false);
  }

  /// Folds matching `food_items` rows into one card per restaurant, carrying a
  /// short hint of WHAT matched — "Burgers, Sandwiches" — so the card says why
  /// it is on screen. Without it a venue search for "fast food" returns a
  /// plain list of restaurant names with no visible connection to the request.
  ///
  /// Ordered by how many items matched, then rating: the closest match first.
  /// Most rows are unrated (rating 0), so rating is a tie-breaker in practice,
  /// and the hint is built from `category` rather than dish names because a
  /// category generalises ("Burgers" reads better than "Burger Chicken BBQ").
  ///
  /// Pure and static so it can be tested without a database — the query half
  /// needs a live PostgREST and lives in `tool/ai_chat_category_probe.sh`.
  /// [matchedTerms] are the patterns the query matched on. They decide whether
  /// a row's hint should name its category or its dish: a row reached the
  /// result set through `category` OR through `name`, and naming the category
  /// of a row that matched by name is actively misleading. Live example — the
  /// concept "pizza" pulls a dish called "Pizza …" that is filed under
  /// `Pâtes`, and the card then claimed "Pâtes" was why it matched. Pass the
  /// patterns and it says "Pizza …" instead. Empty list ⇒ category first,
  /// which is right for the tiers that match on nothing in particular.
  static List<ProductResult> restaurantCardsFromItemRows(
    List<Map<String, dynamic>> rows, {
    List<String> matchedTerms = const [],
    String? Function(dynamic)? resolveImage,
    int maxCards = 15,
    int maxHintParts = 3,
  }) {
    // Insertion-ordered, so venues with an equal match count and equal rating
    // keep the order the database returned instead of shuffling per call.
    final byId = <String, ({Map<String, dynamic> venue, List<String> hints, int n})>{};

    for (final row in rows) {
      final venue = row['restaurants'];
      if (venue is! Map<String, dynamic>) continue;
      final id = (venue['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final label = _matchHintFor(row, matchedTerms);

      final existing = byId[id];
      if (existing == null) {
        byId[id] = (
          venue: venue,
          hints: label == null ? <String>[] : <String>[label],
          n: 1,
        );
      } else {
        if (label != null &&
            existing.hints.length < maxHintParts &&
            !_hintAlreadyCovered(existing.hints, label)) {
          existing.hints.add(label);
        }
        byId[id] = (
          venue: existing.venue,
          hints: existing.hints,
          n: existing.n + 1,
        );
      }
    }

    final ranked = byId.values.toList()
      ..sort((a, b) {
        final byCount = b.n.compareTo(a.n);
        if (byCount != 0) return byCount;
        final ra = (a.venue['rating'] as num?)?.toDouble() ?? 0;
        final rb = (b.venue['rating'] as num?)?.toDouble() ?? 0;
        return rb.compareTo(ra);
      });

    return ranked.take(maxCards).map((e) {
      final v = e.venue;
      return ProductResult(
        type: 'restaurant',
        id: (v['id'] ?? '').toString(),
        name: (v['name'] ?? '') as String,
        // The hint REPLACES the venue's own description on purpose: the card
        // has one line for it, and "why am I seeing this" is more useful there
        // than generic venue blurb. Falls back to the description when nothing
        // identifiable matched.
        description: e.hints.isEmpty
            ? v['description'] as String?
            : e.hints.join(', '),
        price: 0.0,
        currency: 'TND',
        imageUrl: resolveImage == null
            ? v['image_url'] as String?
            : resolveImage(v['image_url']),
        sourceName: (v['name'] ?? '') as String,
        sourceId: (v['id'] ?? '').toString(),
        rating: (v['rating'] as num?)?.toDouble(),
        deliveryTime: (v['delivery_time_min'] as num?)?.toInt(),
        deliveryFee: (v['delivery_fee'] as num?)?.toDouble(),
      );
    }).toList();
  }

  /// Trimmed, non-empty display label, or null.
  static String? _hintLabel(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// What to show as the reason this row matched: its category when the
  /// category is what matched, otherwise the dish itself. Falls back to
  /// whichever of the two is present.
  static String? _matchHintFor(
    Map<String, dynamic> row,
    List<String> matchedTerms,
  ) {
    final category = _hintLabel(row['category']);
    final dish = _hintLabel(row['name']);
    if (matchedTerms.isEmpty) return category ?? dish;

    bool hits(String? value) {
      if (value == null) return false;
      final folded = ChatVocabulary.foldAccents(value);
      return matchedTerms.any((t) => folded.contains(ChatVocabulary.foldAccents(t)));
    }

    if (hits(category)) return category;
    if (hits(dish)) return dish;
    return category ?? dish;
  }

  /// True when an existing hint already says this, allowing for the
  /// catalogue's singular/plural pairs — "Sandwich" next to "Sandwiches" on
  /// one card is noise, not information.
  static bool _hintAlreadyCovered(List<String> hints, String candidate) {
    final c = ChatVocabulary.foldAccents(candidate);
    return hints.any((h) {
      final existing = ChatVocabulary.foldAccents(h);
      return existing == c ||
          existing.contains(c) ||
          c.contains(existing);
    });
  }

  /// Restaurants that have at least one available item matching the concept.
  ///
  /// Reads `food_items` rather than `restaurants` because the match lives in
  /// the menu, and aggregates to one card per venue. The row limit is high on
  /// purpose: a venue search needs enough of the menu to see every restaurant
  /// that qualifies, not the first page of dishes (403 items are available in
  /// total, so this reads at most most of them, once, per tier).
  Future<List<ProductResult>> _fetchRestaurantsSelling(
    ChatIntent intent,
    List<String> conceptPatterns, {
    required bool useKeyword,
    required bool useCategory,
  }) async {
    try {
      var query = _supabase.from('food_items').select('''
        name, category, price, discount_price, restaurant_id,
        restaurants!inner (id, name, description, image_url, rating,
                           review_count, delivery_time_min, delivery_fee, is_open)
      ''').eq('is_available', true).eq('restaurants.is_open', true);

      // The budget belongs to the user, so it filters here too: a restaurant
      // only qualifies if what matched is actually within what they can spend.
      // No tier drops it.
      if (intent.maxPrice != null) query = query.lte('price', intent.maxPrice!);
      if (intent.minPrice != null) query = query.gte('price', intent.minPrice!);

      final orParts = <String>[];
      if (useCategory) {
        for (final p in conceptPatterns) {
          orParts.add('category.ilike.%$p%');
          orParts.add('name.ilike.%$p%');
        }
      }
      if (useKeyword) {
        final kw = intent.keyword!.trim();
        orParts.add('category.ilike.%$kw%');
        orParts.add('name.ilike.%$kw%');
      }
      // One OR clause: repeated .or() calls AND together in PostgREST, and
      // here every alternative is a way of matching the same request.
      if (orParts.isNotEmpty) query = query.or(orParts.join(','));

      final rows = await query.limit(400) as List<dynamic>;
      return restaurantCardsFromItemRows(
        rows.cast<Map<String, dynamic>>(),
        matchedTerms: [
          if (useCategory) ...conceptPatterns,
          if (useKeyword) intent.keyword!.trim(),
        ],
        resolveImage: _resolveImageUrl,
      );
    } catch (e) {
      debugPrint('AiChatService – restaurants-selling query error: $e');
      throw QueryFailure('restaurant', e);
    }
  }

  /// Widest tier: the open venues themselves, nothing matched against.
  Future<List<ProductResult>> _fetchOpenRestaurants() async {
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

      // Nothing is matched against here on purpose. The concept and the
      // keyword are matched against the MENUS, in _fetchRestaurantsSelling —
      // this tier is reached only once both have been given up, so there is
      // nothing left to filter on. (The old `categories.cs.{…}` tag match
      // lived here and was dead weight twice over: array containment is
      // case-sensitive, so `cs.{pizza}` missed the one tagged row, which
      // holds `["Pizza"]`, and 11 of the 12 rows have an empty array.)
      //
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
      // See queryFoodItems: a failure is not an empty catalogue.
      throw QueryFailure('restaurant', e);
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
  static List<({bool keyword, bool category})> relaxationPlan({
    required bool hasKeyword,
    required bool hasCategory,
  }) =>
      [
        (keyword: hasKeyword, category: hasCategory),
        if (hasKeyword) (keyword: false, category: hasCategory),
        if (hasCategory) (keyword: false, category: false),
      ];

  Future<({List<ProductResult> items, bool relaxed})> queryShopItems(
    ChatIntent intent,
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
    ChatIntent intent, {
    required bool useKeyword,
    required bool useCategory,
  }) async {
    try {
      // `vendors.is_open` filtered HERE, server-side, not in Dart after the
      // fact. The closed-shop check used to run below, on rows that
      // `.limit(20)` had already trimmed: the 20 cheapest matching items were
      // picked across open AND closed shops and only then thinned, so a
      // catalogue search could come back empty while an open shop held
      // matching items. Same defect the food query had, and worse here
      // because of the relaxation tiers above — an all-closed page of rows
      // reads as "this tier found nothing" and relaxes a search that did in
      // fact match, then tells the user so.
      var query = _supabase.from('vendor_items').select('''
        id, name, description, price, discount_price, image_url, category,
        vendors!inner (id, name, image_url, rating, is_open, category)
      ''')
          .eq('is_available', true)
          .eq('vendors.category', slug)
          .eq('vendors.is_open', true);

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
          // The embedded `vendors.is_open` filter above already guarantees
          // this; the null guard stays so an embed shape change drops a row
          // rather than crashing the cast below.
          .where((r) => r['vendors'] != null)
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
      // Propagates out of the relaxation loop in queryShopItems on purpose:
      // a broken query is not a tier that "found nothing", so retrying the
      // next tier would just repeat the same failure and end up reporting an
      // empty shop. See queryFoodItems.
      throw QueryFailure('shop', e);
    }
  }

  // ── Image URL resolver ────────────────────────────────────────────────────

  String? _resolveImageUrl(dynamic raw) {
    if (raw == null) return null;
    final url = raw.toString().trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$_storageBase$url';
  }
}
