// A venue type is not a dish.
//
// "pizzeria", "fast food", "resto tunisien" name a PLACE; "une pizza thon",
// "un burger" name something to eat. The assistant routes the first to
// restaurant_search and the second to search_food — and the venue search has
// to match on what a restaurant SELLS, because matching its name or its
// `categories` tags finds almost nothing: 11 of the 12 live rows have an
// empty tag array, so "fast food" reached no venue at all while 9 open
// restaurants sell burgers, sandwiches, chapati or makloub.
//
// Split of responsibilities in these tests:
//   * the aggregation (rows → one card per venue, with a "why" hint) is pure
//     and tested here, on fixtures shaped like the live rows;
//   * the ROUTING lives in the system prompt, inside the edge function, and
//     only a deployment can be asked what it would answer;
//   * the QUERY needs a live PostgREST.
// The last two are covered by `tool/ai_chat_category_probe.sh venues`, which
// asserts the real counts against the real database after a deploy.

import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/models/chat_message.dart';
import 'package:cmandili_mobile/features/ai_chat/data/ai_chat_service.dart';

/// A `food_items` row with its embedded restaurant, shaped like PostgREST's.
Map<String, dynamic> row(
  String venueId,
  String venueName,
  String dish,
  String? category, {
  double rating = 0,
  String? venueDescription,
}) =>
    {
      'name': dish,
      'category': category,
      'price': 10,
      'restaurant_id': venueId,
      'restaurants': <String, dynamic>{
        'id': venueId,
        'name': venueName,
        'description': venueDescription,
        'image_url': null,
        'rating': rating,
        'review_count': 0,
        'delivery_time_min': 30,
        'delivery_fee': 2,
        'is_open': true,
      },
    };

List<String> namesOf(List<ProductResult> cards) =>
    cards.map((c) => c.name).toList();

void main() {
  group('a venue type returns restaurants, one card each', () {
    // Mirrors the live result for "pizzeria" → concept ['pizza']: six open
    // restaurants sell pizza. Two of them are the ones whose NAME says so;
    // Piccolo Mondo and Titanic food sell eight pizzas each and used to be
    // invisible, which is the whole point of matching on the menu.
    final pizzaRows = [
      ...List.generate(8, (i) => row('t', 'Titanic food', 'Pizza $i', 'Nos Pizza')),
      ...List.generate(8, (i) => row('p', 'Piccolo Mondo', 'Pizza $i', 'Pizzas')),
      ...List.generate(5, (i) => row('m', 'mecano pizza Kairouan', 'Pizza $i', 'Pizza')),
      ...List.generate(2, (i) => row('b', 'plan b', 'Pizza $i', 'Pizza')),
      row('x', 'Texas food', 'Pizza', 'Pizza'),
      row('s', 'Seven pizza Kairouan', 'Pizza', 'Pizza'),
    ];

    test('"pizzeria" returns the pizza sellers, including the two named ones',
        () {
      final cards = AiChatService.restaurantCardsFromItemRows(
        pizzaRows,
        matchedTerms: AiChatService.expandFoodConcept('pizzeria'),
      );
      // The two the brief named explicitly.
      expect(namesOf(cards),
          containsAll(['Seven pizza Kairouan', 'mecano pizza Kairouan']));
      // And the ones that sell pizza without saying so in their name — the
      // reason for this change. Note this is MORE than the brief's two: by
      // "what they sell", Piccolo Mondo and Titanic food genuinely qualify.
      expect(namesOf(cards), containsAll(['Piccolo Mondo', 'Titanic food']));
      expect(cards, hasLength(6));
    });

    test('every card is a restaurant, never a dish', () {
      final cards = AiChatService.restaurantCardsFromItemRows(pizzaRows);
      expect(cards.map((c) => c.type).toSet(), {'restaurant'});
      // A venue card carries no price of its own: it is not orderable, it is
      // a place to open.
      expect(cards.map((c) => c.price).toSet(), {0.0});
      for (final c in cards) {
        expect(c.sourceId, isNotEmpty, reason: 'needed to navigate to it');
        expect(c.sourceName, c.name);
      }
    });

    test('one card per venue however many of its dishes matched', () {
      final cards = AiChatService.restaurantCardsFromItemRows(pizzaRows);
      expect(cards.map((c) => c.id).toSet(), hasLength(cards.length));
    });

    test('the closest match comes first', () {
      final cards = AiChatService.restaurantCardsFromItemRows(pizzaRows);
      // 8 matches beats 5 beats 1.
      expect(cards.first.name, anyOf('Titanic food', 'Piccolo Mondo'));
      expect(cards.last.name, anyOf('Texas food', 'Seven pizza Kairouan'));
    });

    test('"fast food" reaches the venues that sell fast-food items', () {
      final terms = AiChatService.expandFoodConcept('fast food');
      final rows = [
        ...List.generate(17, (i) => row('c', 'Charlot', 'Burger $i', 'Burgers')),
        ...List.generate(11, (i) => row('s', 'Seven pizza Kairouan', 'S $i', 'Sandwiches')),
        ...List.generate(19, (i) => row('r', 'restaurant', 'Chapati $i', 'Chapati')),
        row('f', 'food', 'Malfouf', 'Malfouf'),
      ];
      final cards = AiChatService.restaurantCardsFromItemRows(
        rows,
        matchedTerms: terms,
      );
      expect(namesOf(cards),
          containsAll(['Charlot', 'Seven pizza Kairouan', 'restaurant', 'food']));
      expect(cards.map((c) => c.type).toSet(), {'restaurant'});
    });
  });

  group('the card says WHY it is on screen', () {
    test('the hint names what matched, like "Burgers, Sandwiches"', () {
      final cards = AiChatService.restaurantCardsFromItemRows(
        [
          row('c', 'Charlot', 'Double burger', 'Burgers'),
          row('c', 'Charlot', 'Club', 'Sandwiches'),
        ],
        matchedTerms: AiChatService.expandFoodConcept('fast food'),
      );
      expect(cards.single.description, 'Burgers, Sandwiches');
    });

    test('a row that matched by DISH name is not labelled with its category',
        () {
      // Live case: the concept "pizza" pulls a dish called "Pizza bolognaise"
      // filed under `Pâtes`, and the card used to claim "Pâtes" was the
      // match. Naming the category of a name-match misleads.
      final cards = AiChatService.restaurantCardsFromItemRows(
        [row('p', 'Piccolo Mondo', 'Pizza bolognaise', 'Pâtes')],
        matchedTerms: ['pizza'],
      );
      expect(cards.single.description, 'Pizza bolognaise');
      expect(cards.single.description, isNot(contains('Pâtes')));
    });

    test('the category wins when the category is what matched', () {
      final cards = AiChatService.restaurantCardsFromItemRows(
        [row('p', 'Piccolo Mondo', 'Margherita', 'Pizzas')],
        matchedTerms: ['pizza'],
      );
      expect(cards.single.description, 'Pizzas');
    });

    test('singular and plural of one word do not both appear', () {
      final cards = AiChatService.restaurantCardsFromItemRows(
        [
          row('x', 'Texas food', 'A', 'Sandwiches'),
          row('x', 'Texas food', 'B', 'Sandwich'),
          row('x', 'Texas food', 'C', 'Burgers'),
        ],
        matchedTerms: AiChatService.expandFoodConcept('fast food'),
      );
      expect(cards.single.description, 'Sandwiches, Burgers');
    });

    test('the hint stays short', () {
      final rows = List.generate(
          9, (i) => row('t', 'Titanic food', 'Dish $i', 'Category$i'));
      final cards = AiChatService.restaurantCardsFromItemRows(rows);
      expect(cards.single.description!.split(', '), hasLength(3));
    });

    test('with nothing identifiable, the venue keeps its own description', () {
      final cards = AiChatService.restaurantCardsFromItemRows([
        row('t', 'Titanic food', '  ', null, venueDescription: 'Cuisine italienne'),
      ]);
      expect(cards.single.description, 'Cuisine italienne');
    });
  });

  group('malformed rows are dropped, not crashed on', () {
    test('a row with no embedded restaurant is skipped', () {
      final cards = AiChatService.restaurantCardsFromItemRows([
        {'name': 'Orphan', 'category': 'Pizza', 'restaurants': null},
        row('p', 'Piccolo Mondo', 'Margherita', 'Pizzas'),
      ]);
      expect(namesOf(cards), ['Piccolo Mondo']);
    });

    test('a venue with no id is skipped rather than merged into one card', () {
      final bad = row('', '', 'X', 'Pizza');
      final cards = AiChatService.restaurantCardsFromItemRows([bad]);
      expect(cards, isEmpty);
    });

    test('an empty result set is empty, not an error', () {
      expect(AiChatService.restaurantCardsFromItemRows([]), isEmpty);
    });
  });

  group('relaxation stays honest, and the budget is never a tier', () {
    test('the tier plan has no price knob at all', () {
      // Shared by the dish, venue and shop searches now. A tier can give up
      // the keyword and the category; there is deliberately no field it could
      // use to give up the user's budget.
      final plan =
          AiChatService.relaxationPlan(hasKeyword: true, hasCategory: true);
      expect(plan.first.keyword, isTrue);
      expect(plan.first.category, isTrue);
      expect(plan.last.keyword, isFalse);
      expect(plan.last.category, isFalse);
      // The record type is (keyword, category) — adding price would be a
      // compile error here, which is the guarantee.
      expect(plan.map((t) => '${t.keyword}/${t.category}').toList(),
          ['true/true', 'false/true', 'false/false']);
    });

    test('a relaxed dish result admits it is not what was asked', () {
      final notice = AiChatService.relaxedFoodNotice();
      expect(notice, contains('pas trouvé exactement'));
      // Must not promise the cards match, and must not invent anything.
      expect(notice, isNot(matches(RegExp(r'\d'))),
          reason: 'no prices or counts in a notice that claims nothing');
    });

    test('a relaxed venue result admits the same', () {
      final notice = AiChatService.relaxedRestaurantNotice();
      expect(notice, contains('pas trouvé exactement'));
      expect(notice, contains('ouverts'));
    });

    test('the two notices are distinguishable from the empty state', () {
      for (final notice in [
        AiChatService.relaxedFoodNotice(),
        AiChatService.relaxedRestaurantNotice(),
      ]) {
        expect(notice, isNot(AiChatService.noResultsMessageFor('food')));
        expect(notice, isNot(AiChatService.queryFailedMessage()));
      }
    });
  });
}
