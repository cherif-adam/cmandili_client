// Amana Assistant — dishes searched by the function (2026-11-06).
//
// "malfouf thon et calzone" used to come back with koucha and mineral water:
// the model glued both dishes into one keyword, the app's dish ladder found
// nothing, dropped every filter and showed the 20 cheapest open items. The
// `ai-chat` function now searches each named dish itself and sends the rows in
// `dish_results`; these tests lock in the app's half:
//   - dish_results is parsed, nested restaurant included;
//   - its rows become cards as they are;
//   - the app's own dish ladder never ends on the "anything" tier once the
//     user named something.
// The server half (splitting, fuzzy match, per-dish wording) is tested in
// supabase/functions/_shared/dish_search_test.ts and ai-chat/dish_reply_test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/features/ai_chat/data/ai_chat_service.dart';
import 'package:cmandili_mobile/features/ai_chat/data/catalogue_search.dart';
import 'package:cmandili_mobile/features/ai_chat/data/chat_intent.dart';

Map<String, dynamic> _row(String id, String name, String shop) => {
      'id': id,
      'name': name,
      'description': null,
      'price': 18,
      'discount_price': null,
      'image_url': 'vendor-items/$id.jpg',
      'category': 'Sandwiches',
      'restaurant_id': 'r-$shop',
      'restaurants': {
        'id': 'r-$shop',
        'name': shop,
        'image_url': null,
        'rating': 0,
        'delivery_time_min': 30,
        'delivery_fee': 2.5,
        'is_open': true,
      },
    };

void main() {
  group('ChatIntent.fromJson — dish_results', () {
    test('parses each dish, found or not, with its rows', () {
      final intent = ChatIntent.fromJson({
        'message': 'Calzone : trouvé chez Texas food.\n'
            'Malfouf thon : pas disponible pour le moment.',
        'lang': 'fr',
        'intent': 'search_food',
        'status': 'ok',
        'dish_results': [
          {
            'dish': 'Calzone',
            'found': true,
            'items': [_row('1', 'Calzone', 'Texas food')],
          },
          {'dish': 'Malfouf thon', 'found': false, 'items': []},
        ],
      });
      expect(intent.dishResults, hasLength(2));
      expect(intent.dishResults![0].found, isTrue);
      expect(intent.dishResults![0].items.single['name'], 'Calzone');
      expect(intent.dishResults![1].found, isFalse);
      expect(intent.dishResults![1].items, isEmpty);
      expect(intent.status, 'ok');
    });

    test('absent (older function, health goal, no dish named) -> null', () {
      final intent = ChatIntent.fromJson(
          {'message': 'Bonjour', 'intent': 'greeting', 'lang': 'fr'});
      expect(intent.dishResults, isNull);
      expect(intent.status, 'ok');
    });

    test('survives withServiceCategory', () {
      final intent = ChatIntent.fromJson({
        'message': 'x',
        'intent': 'shop_search',
        'status': 'degraded',
        'dish_results': [
          {'dish': 'Calzone', 'found': true, 'items': []},
        ],
      }).withServiceCategory('grocery');
      expect(intent.dishResults, hasLength(1));
      expect(intent.status, 'degraded');
    });
  });

  group('CatalogueSearch.cardsFromFoodRows', () {
    test('one card per row, in the order sent, with the restaurant', () {
      final cards = CatalogueSearch.cardsFromFoodRows([
        _row('1', 'Malfouf Thon', 'plan b'),
        _row('2', 'Malfouf Thon', 'Piccolo Mondo'),
        _row('3', 'Calzone', 'Texas food'),
      ]);
      expect(cards.map((c) => '${c.name} @ ${c.sourceName}'), [
        'Malfouf Thon @ plan b',
        'Malfouf Thon @ Piccolo Mondo',
        'Calzone @ Texas food',
      ]);
      expect(cards.first.type, 'food');
      expect(cards.first.price, 18);
      expect(cards.first.imageUrl, endsWith('/vendor-items/1.jpg'));
    });

    test('a row without its restaurant is dropped, not crashed on', () {
      final broken = _row('1', 'Calzone', 'Texas food')..remove('restaurants');
      expect(CatalogueSearch.cardsFromFoodRows([broken]), isEmpty);
    });
  });

  group('foodRelaxationPlan — never "anything" once something was named', () {
    test('a named dish alone: one tier, no fallback to the whole menu', () {
      expect(
        AiChatService.foodRelaxationPlan(
            hasKeyword: true, hasCategory: false, namedSomething: true),
        [(keyword: true, category: false)],
      );
    });

    test('a dish and a kind of food: the kind of food stays as the fallback', () {
      expect(
        AiChatService.foodRelaxationPlan(
            hasKeyword: true, hasCategory: true, namedSomething: true),
        [(keyword: true, category: true), (keyword: false, category: true)],
      );
    });

    test('nothing named ("j\'ai faim", a vegetarian goal): unchanged', () {
      expect(
        AiChatService.foodRelaxationPlan(
            hasKeyword: true, hasCategory: false, namedSomething: false),
        AiChatService.relaxationPlan(hasKeyword: true, hasCategory: false),
      );
      expect(
        AiChatService.foodRelaxationPlan(
            hasKeyword: false, hasCategory: false, namedSomething: false),
        [(keyword: false, category: false)],
      );
    });
  });
}
