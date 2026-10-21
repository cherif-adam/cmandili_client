// Multi-catalogue assistant — client-side contract.
//
// The assistant used to answer every non-food request with the nutrition
// redirect, and its one shop query read `grocery_items`, a view pinned to
// `vendors.category = 'grocery'`, so bakery / flowers / pets / gifts /
// electronics were unreachable. These tests lock in the client half of the
// fix: the slug allowlist, the backward-compatibility inference (plan risk
// R5) and the honest empty state.
//
// What they deliberately do NOT cover: the system prompt lives in the edge
// function and only an actual deployment can be asked what it would answer.
// `tool/ai_chat_category_probe.sh` does that part, after a deploy.

import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/features/ai_chat/data/ai_chat_service.dart';

void main() {
  group('normaliseServiceCategory — server-sent slug', () {
    test('accepts each of the 7 catalogues', () {
      for (final slug in AiChatService.kServiceCategories) {
        expect(AiChatService.normaliseServiceCategory(slug), slug,
            reason: '$slug should survive normalisation');
      }
    });

    test('maps the aliases an older function build may send', () {
      const cases = {
        'supermarket': 'grocery',
        'Supermarche': 'grocery',
        'patisserie': 'bakery',
        'animalerie': 'pets',
        'cadeaux': 'gifts',
        'restaurant': 'food',
        '  FLOWERS  ': 'flowers',
      };
      cases.forEach((input, expected) {
        expect(AiChatService.normaliseServiceCategory(input), expected,
            reason: '"$input" should map to $expected');
      });
    });

    test('drops anything unknown rather than querying nothing', () {
      for (final junk in ['boutique', 'pharmacie', '', '   ', 42, null]) {
        expect(AiChatService.normaliseServiceCategory(junk), isNull,
            reason: '$junk is not a catalogue');
      }
    });
  });

  group('inferServiceCategory — one request per category (R5 fallback)', () {
    const perCategory = <String, String>{
      // FR, the phrasings from the bug report and the brief
      'Je peux commander un bouquet de fleur': 'flowers',
      "je peux acheter des produits d'animalerie ?": 'pets',
      'des croquettes pour chat': 'pets',
      'je cherche un chargeur de telephone': 'electronics',
      'un cadeau pour ma mère': 'gifts',
      "un gâteau d'anniversaire": 'bakery',
      'il me faut du lait et du shampoing': 'grocery',
      // EN
      'do you sell phone chargers?': 'electronics',
      'I want to buy flowers': 'flowers',
      // Tunisian Derja, Latin script
      'n7eb nechri zhour l omi': 'flowers',
      'n7eb cadeau l khouya': 'gifts',
    };

    perCategory.forEach((text, expected) {
      test('"$text" → $expected', () {
        expect(AiChatService.inferServiceCategory(text), expected);
      });
    });

    test('handles accents and plurals', () {
      expect(AiChatService.inferServiceCategory('des fleurs'), 'flowers');
      expect(AiChatService.inferServiceCategory('une litière'), 'pets');
      expect(AiChatService.inferServiceCategory('des cadeaux'), 'gifts');
      expect(AiChatService.inferServiceCategory('faire les courses'), 'grocery');
    });
  });

  group('inferServiceCategory — must NOT hijack', () {
    test('a nutrition request stays out of every shop catalogue', () {
      // The specialisation is the feature. If any of these inferred a
      // catalogue, the food path would be stolen from RULES 3/4.
      const nutrition = [
        'je fais un régime, qu\'est-ce que je peux manger ?',
        'je fais de la musculation, qu\'est-ce que tu me conseilles ?',
        'chnoua el a7sen lel cholestérol ?',
        'un plat pour diabétique',
        'je veux manger sain',
      ];
      for (final q in nutrition) {
        expect(AiChatService.inferServiceCategory(q), isNull,
            reason: '"$q" is a nutrition question, not a shop search');
      }
    });

    test('an off-topic request infers nothing', () {
      const offTopic = [
        'quel temps fait-il à Kairouan ?',
        'raconte moi une blague',
        'who won the match yesterday',
      ];
      for (final q in offTopic) {
        expect(AiChatService.inferServiceCategory(q), isNull);
      }
    });

    test('ordinary food wording is not dragged into a catalogue', () {
      const food = [
        'je veux une pizza thon',
        'une salade de laitue',      // 'lait' must not fire on 'laitue'
        'un couscous',                // 'course' must not fire on 'couscous'
        'laisse tomber',              // must not fire on pets
      ];
      for (final q in food) {
        expect(AiChatService.inferServiceCategory(q), isNull,
            reason: '"$q" should not infer a shop catalogue');
      }
    });

    test('empty input is safe', () {
      expect(AiChatService.inferServiceCategory(''), isNull);
      expect(AiChatService.inferServiceCategory('   '), isNull);
    });
  });

  group('noResultsMessageFor — honest and inventive of nothing', () {
    test('names the catalogue that was searched', () {
      expect(AiChatService.noResultsMessageFor('flowers'),
          contains('fleuriste'));
      expect(AiChatService.noResultsMessageFor('pets'), contains('animalerie'));
      expect(AiChatService.noResultsMessageFor('bakery'),
          contains('pâtisserie'));
    });

    test('suggests a neighbouring catalogue without promising stock', () {
      final msg = AiChatService.noResultsMessageFor('flowers');
      expect(msg, contains('magasin de cadeaux'));
      // Conditional wording only — never "il y en a chez X". Was "si tu veux"
      // until French went to "vous" throughout (see ai_chat_tone_lang_test).
      expect(msg, contains('si vous voulez'));
    });

    test('never fabricates a shop name, product or price', () {
      for (final slug in AiChatService.kServiceCategories) {
        final msg = AiChatService.noResultsMessageFor(slug);
        expect(msg, isNot(contains('TND')), reason: 'no price in $slug');
        expect(RegExp(r'\d').hasMatch(msg), isFalse,
            reason: 'no digits (price/quantity) in $slug: $msg');
      }
    });

    test('falls back to the generic line for an unknown slug', () {
      final msg = AiChatService.noResultsMessageFor(null);
      expect(msg, contains('Aucun résultat'));
    });
  });

  group('budget — the empty state names it instead of blaming the shop', () {
    test('an upper bound is stated, in each catalogue', () {
      for (final slug in AiChatService.kServiceCategories) {
        final msg = AiChatService.noResultsMessageFor(slug, maxPrice: 40);
        expect(msg, contains('sous 40 TND'), reason: 'for $slug: $msg');
      }
    });

    test('a range and a lower bound are stated too', () {
      expect(
        AiChatService.noResultsMessageFor('gifts', maxPrice: 50, minPrice: 20),
        contains('entre 20 et 50 TND'),
      );
      expect(
        AiChatService.noResultsMessageFor('gifts', minPrice: 30),
        contains('au-dessus de 30 TND'),
      );
    });

    test('whole amounts print without decimals', () {
      // The LLM sends 40 or 40.0 depending on the provider; both must read
      // as "40 TND", never "40.0 TND".
      expect(AiChatService.noResultsMessageFor('flowers', maxPrice: 40.0),
          contains('sous 40 TND'));
      expect(AiChatService.noResultsMessageFor('flowers', maxPrice: 40),
          contains('sous 40 TND'));
    });

    test('suggests widening the budget rather than implying the shop is empty',
        () {
      final msg = AiChatService.noResultsMessageFor('flowers', maxPrice: 40);
      expect(msg, contains('budget'));
      expect(msg, isNot(contains('la boutique est fermée')));
    });

    test('without a budget the wording is unchanged', () {
      final msg = AiChatService.noResultsMessageFor('flowers');
      expect(msg, contains('fleuriste'));
      expect(msg, isNot(contains('TND')));
    });
  });

  group('relaxationPlan — the budget is never a tier', () {
    test('no tier can drop the price: the record has no price knob', () {
      final plan = AiChatService.relaxationPlan(
          hasKeyword: true, hasCategory: true);
      // Every tier is described by exactly (keyword, category). If a price
      // flag is ever added here, this test should be revisited on purpose.
      for (final tier in plan) {
        expect(tier.keyword, isA<bool>());
        expect(tier.category, isA<bool>());
      }
    });

    test('drops the keyword first, then the sub-category', () {
      final plan = AiChatService.relaxationPlan(
          hasKeyword: true, hasCategory: true);
      expect(plan, hasLength(3));
      expect(plan[0], (keyword: true, category: true));
      expect(plan[1], (keyword: false, category: true));
      expect(plan[2], (keyword: false, category: false));
    });

    test('emits no duplicate tier when a filter is absent', () {
      expect(
        AiChatService.relaxationPlan(hasKeyword: true, hasCategory: false),
        [(keyword: true, category: false), (keyword: false, category: false)],
      );
      expect(
        AiChatService.relaxationPlan(hasKeyword: false, hasCategory: true),
        [(keyword: false, category: true), (keyword: false, category: false)],
      );
      expect(
        AiChatService.relaxationPlan(hasKeyword: false, hasCategory: false),
        [(keyword: false, category: false)],
      );
    });
  });

  group('relaxedNoticeFor — says the cards are stock, not matches', () {
    test('never claims the items match what was asked', () {
      for (final slug in AiChatService.kServiceCategories) {
        final msg = AiChatService.relaxedNoticeFor(slug);
        expect(msg, contains("pas trouvé exactement"),
            reason: 'must admit the miss for $slug');
      }
    });

    test('uses the right French article for each shop', () {
      expect(AiChatService.relaxedNoticeFor('flowers'),
          contains('le fleuriste'));
      expect(AiChatService.relaxedNoticeFor('pets'),
          contains("l'animalerie"));
      expect(AiChatService.relaxedNoticeFor('bakery'),
          contains('la pâtisserie'));
      expect(AiChatService.relaxedNoticeFor('electronics'),
          contains("le magasin d'électronique"));
    });

    test('invents no product or price', () {
      for (final slug in AiChatService.kServiceCategories) {
        final msg = AiChatService.relaxedNoticeFor(slug);
        expect(msg, isNot(contains('TND')));
        expect(RegExp(r'\d').hasMatch(msg), isFalse, reason: msg);
      }
    });

    test('handles an unknown slug without crashing', () {
      expect(AiChatService.relaxedNoticeFor(null),
          contains("pas trouvé exactement"));
    });
  });
}
