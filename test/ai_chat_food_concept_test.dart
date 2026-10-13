// The model's food vocabulary vs. the catalogue's.
//
// `category` comes back from the edge function as free text and became
// `category ilike '%<text>%'`, ANDed, with nothing to fall back on. Measured
// live 2026-10-13: "fast food" matched 0 of 403 available items while
// Chapati (34), Sandwiches (28), Malfouf (22), Burgers (13) and the three
// Makloub spellings (14) all sat there unreachable. The same five stems as an
// OR returned 124 rows.
//
// These tests cover the resolution step only. Wiring it into the tiered food
// and restaurant queries is the rest of step A and is not done yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/services/ai_chat_service.dart';

void main() {
  group('expandFoodConcept — umbrella concepts reach the real words', () {
    test('"fast food" stops being a dead end', () {
      final out = AiChatService.expandFoodConcept('fast food');
      expect(out, isNot(['fast food']),
          reason: 'the literal term matches nothing in the catalogue');
      expect(out, containsAll(['burger', 'sandwich', 'chapati', 'makloub']));
    });

    test('its spellings and languages all land on the same concept', () {
      final expected = AiChatService.expandFoodConcept('fast food');
      for (final variant in ['fastfood', 'Fast-Food', 'FAST  FOOD', 'snack',
        'street food']) {
        expect(AiChatService.expandFoodConcept(variant), expected,
            reason: '"$variant" should resolve like "fast food"');
      }
    });

    test('Tunisian home cooking resolves, in French and in Derja', () {
      for (final term in ['makla tounsia', 'tounsi', 'tunisien', 'tunisian']) {
        expect(AiChatService.expandFoodConcept(term),
            containsAll(['makloub', 'malfouf', 'tabouna']),
            reason: '"$term" should reach the Tunisian dishes');
      }
    });

    test('"quelque chose de leger" style concepts reach salads and soups', () {
      for (final term in ['leger', 'léger', 'light', 'healthy']) {
        expect(AiChatService.expandFoodConcept(term),
            containsAll(['salad', 'soup']));
      }
    });
  });

  group('expandFoodConcept — spelling variants of one thing', () {
    test('a stem covers the catalogue\'s three spellings', () {
      // 'Salades' and 'Salads' are both live values; 'salad' is the substring
      // that reaches both, which 'salade' alone would not.
      expect(AiChatService.expandFoodConcept('salade'), ['salad']);
      expect(AiChatService.expandFoodConcept('salad'), ['salad']);
    });

    test('accented values keep both forms, because ilike does not fold', () {
      // 'Pâtes' is a live category and '%pate%' does not match it.
      final out = AiChatService.expandFoodConcept('pates');
      expect(out, contains('pâtes'));
      expect(out, contains('pasta'));
    });

    test('a plural the model happened to emit still resolves', () {
      expect(AiChatService.expandFoodConcept('burgers'),
          AiChatService.expandFoodConcept('burger'));
      expect(AiChatService.expandFoodConcept('boissons'),
          AiChatService.expandFoodConcept('boisson'));
    });
  });

  group('expandFoodConcept — never makes a search worse', () {
    test('an unknown term is searched unchanged, not dropped', () {
      // The map is a widening, not an allowlist: a dish name the model knows
      // and this map does not must still reach the catalogue.
      expect(AiChatService.expandFoodConcept('chawarma'), ['chawarma']);
      expect(AiChatService.expandFoodConcept('Margherita'), ['Margherita']);
    });

    test('blank input asks for no filter at all', () {
      for (final blank in [null, '', '   ']) {
        expect(AiChatService.expandFoodConcept(blank), isEmpty,
            reason: 'an absent category must not become a filter');
      }
    });

    test('punctuation-only input does not become an empty ilike', () {
      // '%%' matches every row, which would silently widen the search.
      expect(AiChatService.expandFoodConcept('???'), ['???']);
    });
  });

  group('every pattern is safe inside a PostgREST or=(…) list', () {
    test('no comma, quote, slash or parenthesis in any value', () {
      // A comma would split the term and PostgREST would parse the remainder
      // as another filter; the rest break the expression outright. This is why
      // live categories like "Lasagne / Gratin" and "Hors d'oeuvre" are
      // reached by stems ('lasagne', 'gratin', 'oeuvre') instead of verbatim.
      final offenders = <String>[];
      for (final concept in AiChatService.foodConceptsForTest.entries) {
        for (final pattern in concept.value) {
          if (RegExp(r"[,'/()]").hasMatch(pattern)) {
            offenders.add('${concept.key} → "$pattern"');
          }
          expect(pattern.trim(), pattern,
              reason: 'untrimmed pattern in ${concept.key}');
          expect(pattern, isNotEmpty);
        }
      }
      expect(offenders, isEmpty,
          reason: 'these would break the or=(…) filter: $offenders');
    });

    test('every alias points at a concept that exists', () {
      for (final target in AiChatService.foodConceptAliasesForTest.values) {
        expect(AiChatService.foodConceptsForTest.containsKey(target), isTrue,
            reason: '"$target" is an alias target with no concept behind it');
      }
    });

    test('concept keys are already normalised, so lookups cannot miss', () {
      final keyShape = RegExp(r'^[a-z0-9]+( [a-z0-9]+)*$');
      for (final key in AiChatService.foodConceptsForTest.keys) {
        expect(key, matches(keyShape),
            reason: '"$key" would never be reached: lookup folds accents, '
                'lowercases and collapses separators to single spaces');
      }
    });
  });
}
