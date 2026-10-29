// Phone test, 29/10/2026, app in French, conversation in Derja:
//   "ena naaml fi régime w f sport nhebk tansa7ni B plat yfidni"
//   "a5tarli haja behya"
// The advice was right (grilled chicken, fish, salads, legumes) and the cards
// under it were makloub, chapati, malfouf: the search ORed poulet/thon/viande
// over the whole menu and kept the cheapest, which are street food. And
// "hello" got an English greeting.
//
// The AI is mocked (no Gemini call); the menu rows are real dishes from the
// live menu of that day (names, sections, prices).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/features/ai_chat/data/ai_chat_service.dart';
import 'package:cmandili_mobile/features/ai_chat/data/chat_wording.dart';
import 'package:cmandili_mobile/features/ai_chat/data/healthy_food_rules.dart';

const _turn1 = 'ena naaml fi régime w f sport nhebk tansa7ni B plat yfidni';
const _turn2 = 'a5tarli haja behya';

const _venue = {
  'id': 'r1',
  'name': 'Dar Elaiz',
  'image_url': null,
  'rating': 0,
  'delivery_time_min': 30,
  'delivery_fee': 3,
  'is_open': true,
};

Map<String, dynamic> _dish(String name, String category, num price) => {
      'id': name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      'name': name,
      'description': null,
      'price': price,
      'discount_price': null,
      'image_url': null,
      'category': category,
      'is_spicy': false,
      'is_vegetarian': false,
      'preparation_time': 20,
      'restaurant_id': 'r1',
      'restaurants': _venue,
    };

/// What the light query would bring back: everything with a light word in it,
/// heavy dishes included (they have "thon", "poulet", "grillées"...).
final _heavy = [
  _dish('Makloub Thon', 'Makloubs', 7.7),
  _dish('Chapati omlette Thon', 'Chapati', 2.5),
  _dish('Malfouf Thon', 'Malfouf', 3.5),
  _dish('Tabouna Thon', 'Nos Tabouna', 7.7),
  _dish('Calzone Thon', 'Calzones', 8.3),
  _dish('Mlawi Thon Fromage', 'Nos Mlawis', 5.4),
  _dish('Cornet Thon', 'Cornets', 7.7),
  _dish('Pizza Thon', 'Pizza', 11.9),
  _dish('Tacos Poulet', 'Sandwiches', 12),
  _dish('Chapati Poulet', 'Sandwiches', 9),
  _dish('POULET PANÉ AUX AMANDES', 'Sandwiches', 7),
  _dish('Salade Poulet Croustillant', 'Salads', 13),
  _dish('Friture de Poisson', 'Seafood', 22),
  _dish('Merguez Grillées', 'Grills', 13),
  _dish("Brik à l'Œuf", 'Starters', 4),
  _dish('Lasagne Poulet', 'Lasagne / Gratin', 14),
  _dish('Burger Poulet', 'Burgers', 11),
  _dish('Coca Cola Light', 'Boissons', 2.5),
];
final _light = [
  _dish('Poulet Grillé 1/4', 'Poulet', 12),
  _dish('Poulet Roti 1/4', 'Poulet', 12),
  _dish('Daurade Grillée', 'Poissons', 12),
  _dish('Loup Grillé', 'Poissons', 12),
  _dish('Salade Mechouia', 'Salads', 7),
  _dish('Salade Healthy', 'Salades', 8),
  _dish('Soupe de Poisson', 'Soups', 9),
  _dish('Escalope Grillée', 'Volailles', 19),
  _dish('Kefta Grillée', 'Grills', 16),
];
final _neutral = [_dish('Spaghetti au Boeuf', 'Pâtes', 21.4)];

Set<String> _names(List<Map<String, dynamic>> rows) => {for (final r in rows) r['name'] as String};

// ── Fake Supabase: the ai-chat function and the food_items table ───────────

final _requests = <String>[];
final _fnReplies = <Map<String, dynamic>>[];
var _foodRows = <Map<String, dynamic>>[];

http.Response _json(Object? body, http.BaseRequest req) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: req,
    );

Future<http.Response> _handle(http.Request req) async {
  if (req.url.path.endsWith('/functions/v1/ai-chat')) {
    _requests.add('FUNCTION ${req.body}');
    return _json(_fnReplies.removeAt(0), req);
  }
  final table = req.url.path.split('/').last;
  _requests.add('$table?${Uri.decodeQueryComponent(req.url.query)}');
  return _json(table == 'food_items' ? _foodRows : const [], req);
}

Map<String, dynamic> _reply(String message, {String? goal, String? keyword, String? category}) => {
      'message': message,
      'lang': 'tn',
      'intent': 'search_food',
      'health_goal': goal,
      'service_category': 'food',
      'category': category,
      'spicy': null,
      'vegetarian': null,
      'max_price': null,
      'min_price': null,
      'delivery_time': null,
      'keyword': keyword,
    };

const _advice = 'Mabrouk 3lik el régime w el sport! Bech tzid tqawwi ro7ek, a7sen 7aja hiya el '
    'makla elli fiha barcha protéines w chwaya droub. El poulet el mchwi, el 7out, w el salades '
    'b les légumineuses y3awnouk barcha. Hani nchouflek chnoua famma! 💪';
const _followUp = 'Behi! Nchouflek el a7sen plat mchwi, ghani bel protéines w yfid lel sport w '
    'el régime. Hani nchouf!';

void main() {
  group('HealthyFoodRules: the goal', () {
    test('the first message names a diet and sport, in Derja', () {
      expect(HealthyFoodRules.goalsInText(_turn1), {'diet', 'sport'});
    });

    test('"a5tarli haja behya" alone names no goal, but carries the earlier one', () {
      expect(HealthyFoodRules.goalsInText(_turn2), isEmpty);
      expect(HealthyFoodRules.lightGoalsFor(userText: _turn2, earlierUserTexts: [_turn1]),
          {'diet', 'sport'});
    });

    test('the model goal wins; vegetarian and iftar keep their own search', () {
      expect(HealthyFoodRules.lightGoalsFor(modelGoal: 'sport', userText: _turn1), {'sport'});
      expect(HealthyFoodRules.lightGoalsFor(modelGoal: 'vegetarian', userText: _turn1), isEmpty);
      expect(HealthyFoodRules.lightGoalsFor(modelGoal: 'iftar', userText: 'iftar'), isEmpty);
    });

    test('a named heavy dish after a diet is a request for that dish', () {
      expect(
          HealthyFoodRules.lightGoalsFor(
              userText: 'w nheb chapati', earlierUserTexts: [_turn1], keyword: 'chapati'),
          isEmpty);
    });

    test('French, English and Arabic goals are read; ordinary words are not', () {
      expect(HealthyFoodRules.goalsInText('Je fais un régime, je veux manger léger'), {'diet'});
      expect(HealthyFoodRules.goalsInText("I'm on a diet and I go to the gym"), {'diet', 'sport'});
      expect(HealthyFoodRules.goalsInText('أنا في حمية'), {'diet'});
      expect(HealthyFoodRules.goalsInText('أمارس الرياضة كل يوم'), {'sport'});
      expect(HealthyFoodRules.goalsInText('je suis diabétique'), {'diabetes'});
      for (final plain in ['salut', 'quelque chose de sucré', 'صحيح، أريد بيتزا', 'un bon resto']) {
        expect(HealthyFoodRules.goalsInText(plain), isEmpty, reason: plain);
      }
    });
  });

  group('HealthyFoodRules: the dishes', () {
    final menu = [..._heavy, ..._light, ..._neutral];

    test('only light dishes, never the fried or heavy ones', () {
      final picked = HealthyFoodRules.pickLightDishes(menu,
          goals: {'sport'}, preferred: 'poulet', askedFor: '$_turn1 poulet');
      expect(_names(picked), _names(_light));
    });

    test('the model keyword comes first: "poulet grillé" puts grilled chicken on top', () {
      final picked = HealthyFoodRules.pickLightDishes(menu,
          goals: {'sport'}, preferred: 'poulet grillé', askedFor: _turn1);
      expect(picked.first['name'], 'Poulet Grillé 1/4');
      // Then every dish with "poulet" or "grillé" in its name, before the rest.
      final names = [for (final r in picked) r['name'] as String];
      final lastMatch = names.lastIndexWhere((n) => RegExp(r'Poulet|Grill').hasMatch(n));
      final firstOther = names.indexWhere((n) => !RegExp(r'Poulet|Grill').hasMatch(n));
      expect(lastMatch, lessThan(firstOther));
    });

    test('a diet puts salads and soups before the rest', () {
      final picked = HealthyFoodRules.pickLightDishes(menu, goals: {'diet'}, askedFor: _turn2);
      expect(_names(picked.take(3).toList()),
          {'Salade Mechouia', 'Salade Healthy', 'Soupe de Poisson'});
    });

    test('a heavy dish the user names stays allowed', () {
      final picked = HealthyFoodRules.pickLightDishes(menu,
          goals: {'diet'}, askedFor: 'w chapati poulet?');
      expect(_names(picked), contains('Chapati Poulet'));
      expect(_names(picked), isNot(contains('Makloub Thon')));
    });

    test('"Œuf" is read as "oeuf"', () {
      expect(HealthyFoodRules.words("Brik à l'Œuf"), ['brik', 'a', 'l', 'oeuf']);
      final picked = HealthyFoodRules.pickLightDishes([_dish('Œufs durs', 'Starters', 3)],
          goals: {'sport'});
      expect(picked, hasLength(1));
    });
  });

  group('the conversation, through the service', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
        debug: false,
        httpClient: MockClient(_handle),
      );
    });

    setUp(() {
      _requests.clear();
      _fnReplies.clear();
      _foodRows = [..._heavy, ..._light, ..._neutral];
    });

    test('turn 1: the cards are the light dishes the advice talks about', () async {
      _fnReplies.add(_reply(_advice, goal: 'sport', keyword: 'poulet'));
      final m = await AiChatService().sendMessage(_turn1, [], appLang: 'fr');

      expect(_requests.first, contains('"app_lang":"fr"'));
      expect(_requests[1], startsWith('food_items?'));
      expect(_requests[1], contains('name.ilike.%grill%'));
      expect(m.text, _advice);
      final cards = {for (final p in m.products!) p.name};
      expect(cards, _names(_light));
      expect(m.products!.first.name, startsWith('Poulet'));
    });

    test('turn 2: "a5tarli haja behya" keeps the goal even when the model drops it', () async {
      _fnReplies.add(_reply(_followUp));
      final history = [
        {'role': 'user', 'parts': [{'text': _turn1}]},
        {'role': 'model', 'parts': [{'text': _advice}]},
      ];
      final m = await AiChatService().sendMessage(_turn2, history, appLang: 'fr');

      expect(_requests[1], contains('name.ilike.%grill%'));
      expect(m.text, _followUp);
      final cards = {for (final p in m.products!) p.name};
      expect(cards, _names(_light));
      expect(cards.intersection(_names(_heavy)), isEmpty);
    });

    test('a named dish is searched as asked', () async {
      _fnReplies.add(_reply('Hani njiblek el chapati 🌯', keyword: 'chapati', category: 'chapati'));
      final history = [
        {'role': 'user', 'parts': [{'text': _turn1}]},
      ];
      await AiChatService().sendMessage('w nheb chapati', history, appLang: 'fr');

      expect(_requests[1], isNot(contains('name.ilike.%grill%')));
      expect(_requests[1], contains('chapati'));
    });

    test('no light dish open: say so, never fall back to the heavy ones', () async {
      _foodRows = [..._heavy];
      _fnReplies.add(_reply(_advice, goal: 'diet'));
      final m = await AiChatService().sendMessage(_turn1, [], appLang: 'fr');

      expect(m.products, isEmpty);
      expect(m.text, ChatWording.noLightDishMessage(lang: 'tn'));
      expect(_requests.where((r) => r.startsWith('food_items?')), hasLength(1));
    });
  });
}
