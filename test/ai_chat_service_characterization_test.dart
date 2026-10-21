// Characterization of AiChatService as it stands (2026-10-21), before it is
// split into smaller files: what it sends to the `ai-chat` Edge Function and
// to each table, and what it hands back, for every intent and failure the
// function can produce.
//
// Each case below runs against a fake Supabase (the HTTP client is replaced,
// nothing leaves the machine) and is recorded as text lines: every request
// (method, table, filters in the order they were built, body) followed by
// the reply (text, intent, cards). The lines are compared with
// test/goldens/ai_chat_service.json, produced once from the code above.
//
// The golden is the contract: a refactor must leave it untouched. To
// re-record it after an INTENDED change, run
//   AI_CHAT_GOLDEN=update flutter test test/ai_chat_service_characterization_test.dart
// and review the diff of the JSON file like any other code change.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/models/chat_message.dart';
import 'package:cmandili_mobile/features/ai_chat/data/ai_chat_service.dart';

const _goldenPath = 'test/goldens/ai_chat_service.json';

/// Every request the service made, in order.
final _log = <String>[];

// What the fake answers. Reset before each case.
Object? _fnReply;
int _fnStatus = 200;
bool _fnNetworkDown = false;

/// Per table: the replies to its successive requests (a JSON value, or an
/// int for an HTTP error status). When the queue is empty: [] / {}.
final _tables = <String, List<Object?>>{};

String _b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

/// A session that never expires, so signing in needs no network.
String _fakeSession() {
  final jwt = '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${_b64({'sub': 'u1', 'exp': 4102444800, 'role': 'authenticated'})}.c2ln';
  return jsonEncode({
    'access_token': jwt,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4102444800,
    'refresh_token': 'r',
    'user': {
      'id': 'u1',
      'aud': 'authenticated',
      'email': 'client@amana.tn',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

http.Response _json(Object? body, int status, http.BaseRequest req) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: req,
    );

Future<http.Response> _handle(http.Request req) async {
  final path = req.url.path;
  if (path.endsWith('/functions/v1/ai-chat')) {
    _log.add('FUNCTION ai-chat ${req.body}');
    if (_fnNetworkDown) throw const SocketException('Network is unreachable');
    return _json(_fnReply, _fnStatus, req);
  }
  final table = path.split('/').last;
  final query = Uri.decodeQueryComponent(req.url.query).replaceAll(RegExp(r'\s+'), ' ');
  _log.add('${req.method} $table?$query${req.body.isEmpty ? '' : ' ${req.body}'}');
  final one = (req.headers['Accept'] ?? req.headers['accept'] ?? '').contains('vnd.pgrst.object');
  final queue = _tables[table];
  final reply = (queue == null || queue.isEmpty) ? null : queue.removeAt(0);
  if (reply is int) return _json({'code': 'PGRST', 'message': 'HTTP $reply'}, reply, req);
  if (one) {
    if (reply == null) return _json({'code': 'PGRST116', 'message': '0 rows'}, 406, req);
    return _json(reply, 200, req);
  }
  if (req.method == 'POST' || req.method == 'DELETE' || req.method == 'PATCH') {
    return reply == null ? http.Response('', 201, request: req) : _json(reply, 201, req);
  }
  return _json(reply ?? [], 200, req);
}

String _describe(ChatMessage m) {
  final cards = (m.products ?? const <ProductResult>[]).map((p) => [
        p.type,
        p.id,
        p.name,
        p.description,
        p.price,
        p.currency,
        p.imageUrl,
        p.sourceName,
        p.sourceId,
        p.rating,
        p.deliveryTime,
        p.deliveryFee,
      ].join(' | '));
  return [
    'REPLY user=${m.isUser} intent=${m.intent} products=${m.products == null ? 'null' : m.products!.length}',
    'TEXT ${m.text}',
    ...cards.map((c) => 'CARD $c'),
  ].join('\n');
}

/// One recorded case.
class _Case {
  const _Case(
    this.name, {
    this.text = '',
    this.history = const [],
    this.reply,
    this.status = 200,
    this.networkDown = false,
    this.tables = const {},
    this.image,
    this.run,
  });

  final String name;
  final String text;
  final List<Map<String, dynamic>> history;
  final Object? reply;
  final int status;
  final bool networkDown;
  final Map<String, List<Object?>> tables;

  /// File name of a picture to send with the message (its extension decides
  /// the MIME type).
  final String? image;

  /// Something other than sendMessage to run.
  final Future<String> Function(AiChatService service)? run;
}

Map<String, dynamic> _intent(String intent, {String message = 'Voici ce que je propose 👇', Map<String, dynamic> extra = const {}}) =>
    {'intent': intent, 'message': message, 'lang': 'fr', ...extra};

Map<String, dynamic> _food(String id, String name, {num price = 12, num? discount, String? image, String category = 'Burgers', Map<String, dynamic>? venue}) => {
      'id': id,
      'name': name,
      'description': 'Bon $name',
      'price': price,
      'discount_price': discount,
      'image_url': image,
      'category': category,
      'is_spicy': false,
      'is_vegetarian': false,
      'preparation_time': 15,
      'restaurant_id': venue?['id'],
      'restaurants': venue,
    };

final _venueA = {
  'id': 'r1',
  'name': 'Seven Pizza',
  'description': 'Pizzeria',
  'image_url': 'restaurants/seven.png',
  'rating': 4.5,
  'review_count': 10,
  'delivery_time_min': 25,
  'delivery_fee': 3,
  'is_open': true,
};
final _venueB = {
  'id': 'r2',
  'name': 'Burger Lab',
  'description': null,
  'image_url': 'https://cdn.example/burger.png',
  'rating': 0,
  'review_count': 0,
  'delivery_time_min': 30,
  'delivery_fee': 2.5,
  'is_open': true,
};

Map<String, dynamic> _shop(String id, String name, {num price = 20, num? discount, String category = 'Bouquets'}) => {
      'id': id,
      'name': name,
      'description': 'Joli $name',
      'price': price,
      'discount_price': discount,
      'image_url': 'vendor_items/$id.jpg',
      'category': category,
      'vendors': {'id': 'v1', 'name': 'Fleurs du Lac', 'image_url': null, 'rating': 4.8, 'is_open': true, 'category': 'flowers'},
    };

final _signedOutCases = <_Case>[
  // ── The function itself fails ────────────────────────────────────────────
  const _Case('function answers 500', text: 'pizza', status: 500, reply: {'error': 'both providers down'}),
  const _Case('network down', text: 'pizza', networkDown: true),
  const _Case('payload is not an object', text: 'pizza', reply: [1, 2]),
  const _Case('payload carries an error', text: 'pizza', reply: {'error': 'bad config', 'details': 'no key'}),
  // ── Reading the intent ───────────────────────────────────────────────────
  _Case('greeting, signed out: nothing persisted', text: 'salut', reply: _intent('greeting', message: 'Bonjour ! 😊')),
  const _Case('empty message falls back per language', text: 'hi', reply: {'intent': 'general', 'message': '  ', 'lang': 'english'}),
  const _Case('no intent reads as general', text: 'ok', reply: {'message': 'D\'accord'}),
  const _Case('history is forwarded as given', text: 'et en dessert ?', history: [
    {'role': 'user', 'parts': [{'text': 'pizza'}]},
    {'role': 'model', 'parts': [{'text': 'Voici des pizzas'}]},
  ], reply: {'intent': 'greeting', 'message': 'Bien sûr'}),
  // ── search_food ──────────────────────────────────────────────────────────
  _Case('dish search with every filter', text: 'burger épicé', reply: _intent('search_food', extra: {
    'category': 'fast food',
    'keyword': 'poulet, frites,Poulet',
    'health_goal': 'sport',
    'spicy': true,
    'vegetarian': true,
    'max_price': 20,
    'min_price': 5,
    'delivery_time': 'fast',
  }), tables: {
    'food_items': [
      [
        _food('f1', 'Burger poulet', price: 14, discount: 11.5, image: 'food/burger.png', venue: _venueB),
        _food('f2', 'Chapati', price: 7, image: 'https://cdn.example/chapati.png', category: 'Chapati', venue: _venueA),
        _food('f3', 'Orphan', venue: null),
      ],
    ],
  }),
  _Case('dish search relaxes its keyword', text: 'margherita', reply: _intent('search_food', extra: {'category': 'pizza', 'keyword': 'margherita'}), tables: {
    'food_items': [
      [],
      [_food('f4', 'Pizza 4 fromages', category: 'Pizzas', venue: _venueA)],
    ],
  }),
  _Case('dish search relaxes down to anything', text: 'couscous royal', reply: _intent('search_food', extra: {'category': 'couscous', 'keyword': 'royal'}), tables: {
    'food_items': [[], [], [_food('f5', 'Makloub', category: 'Makloub', venue: _venueB)]],
  }),
  const _Case('dish search finds nothing within budget (en)', text: 'cheap pizza', reply: {
    'intent': 'search_food', 'message': 'Here you go', 'lang': 'en', 'category': 'pizza', 'max_price': 8,
  }),
  _Case('vegetarian health goal forces the flag', text: 'je suis végétarien', reply: _intent('search_food', extra: {'health_goal': 'vegetarian'}), tables: {
    'food_items': [[_food('f6', 'Salade', category: 'Salades', venue: _venueA)]],
  }),
  _Case('diet goal without keyword', text: 'régime', reply: _intent('search_food', extra: {'health_goal': 'diet'}), tables: {
    'food_items': [[], [_food('f7', 'Soupe', category: 'Soupes', venue: _venueA)]],
  }),
  const _Case('dish query fails (tn)', text: 'pizza', reply: {'intent': 'search_food', 'message': 'Hani nchouf', 'lang': 'tn', 'category': 'pizza'}, tables: {
    'food_items': [400],
  }),
  // ── restaurant_search ────────────────────────────────────────────────────
  _Case('venues selling a concept', text: 'une pizzeria', reply: _intent('restaurant_search', extra: {'category': 'pizza', 'keyword': 'four à bois'}), tables: {
    'food_items': [
      [
        _food('f8', 'Pizza Reine', category: 'Pizzas', venue: _venueA),
        _food('f9', 'Pizza Thon', category: 'Pâtes', venue: _venueA),
        _food('f10', 'Pizza du chef', category: 'Pizza', venue: _venueB),
        _food('f11', 'Sandwich', category: 'Sandwiches', venue: _venueB),
        _food('f12', 'Sandwichs', category: 'Sandwich', venue: _venueB),
        _food('f13', 'Pizza noir', venue: null),
      ],
    ],
  }),
  _Case('venues: nothing to match, best-rated list', text: 'un bon resto', reply: _intent('restaurant_search', extra: {'max_price': 30}), tables: {
    'restaurants': [[_venueA, _venueB]],
  }),
  _Case('venues relax down to the list', text: 'resto japonais', reply: _intent('restaurant_search', extra: {'category': 'sushi', 'keyword': 'maki', 'min_price': 10}), tables: {
    'food_items': [[], []],
    'restaurants': [[_venueB]],
  }),
  const _Case('venues: none at all (ar)', text: 'مطعم', reply: {'intent': 'restaurant_search', 'message': 'سأبحث', 'lang': 'ar', 'category': 'burger'}),
  _Case('venue query fails', text: 'resto', reply: _intent('restaurant_search'), tables: {'restaurants': [500]}),
  // ── shop_search ──────────────────────────────────────────────────────────
  _Case('shop search in the catalogue the function names', text: 'des roses', reply: _intent('shop_search', extra: {
    'service_category': 'flower',
    'category': 'Bouquets',
    'keyword': 'rose',
    'max_price': 50,
    'min_price': 10,
  }), tables: {
    'vendor_items': [[_shop('s1', 'Bouquet de roses', discount: 18), _shop('s2', 'Rose rouge', price: 5)]],
  }),
  _Case('shop catalogue inferred from the words', text: 'des croquettes pour mon chien', reply: _intent('shop_search', extra: {'keyword': 'croquettes'}), tables: {
    'vendor_items': [[], [_shop('s3', 'Croquettes 2kg', category: 'Chien')]],
  }),
  const _Case('shop catalogue defaults to grocery', text: 'bonjour', reply: {'intent': 'shop_search', 'message': 'Je regarde', 'category': 'Laitier'}),
  _Case('shop search relaxes (en)', text: 'a charger', reply: {
    'intent': 'shop_search', 'message': 'Looking', 'lang': 'en', 'service_category': 'electronics', 'keyword': 'charger',
  }, tables: {
    'vendor_items': [[], [_shop('s4', 'Câble USB-C', category: 'Câbles')]],
  }),
  const _Case('shop search finds nothing: points at a neighbour', text: 'gâteau', reply: {
    'intent': 'shop_search', 'message': 'Je regarde', 'service_category': 'bakery', 'category': 'Gâteaux', 'keyword': 'anniversaire',
  }),
  _Case('shop query fails', text: 'lait', reply: _intent('shop_search', extra: {'service_category': 'grocery'}), tables: {'vendor_items': [400]}),
  // ── Other intents, signed out ────────────────────────────────────────────
  _Case('colis, signed out', text: 'envoyer un colis', reply: _intent('delivery_request', message: 'Pour envoyer un colis…')),
  _Case('order tracking, signed out', text: 'où est ma commande', reply: _intent('track_order', message: 'Je vérifie ça !')),
  _Case('facture question, signed out', text: 'payer ma facture STEG', reply: _intent('general', message: 'Pour payer une facture…')),
  _Case('general, not a facture', text: 'raconte une blague', reply: _intent('general', message: 'Je suis là pour vos commandes 🙂')),
  _Case('history, signed out', run: (s) async => (await s.loadHistory()).map(_describe).join('\n')),
  _Case('clear, signed out', run: (s) async => 'cleared=${await s.clearHistory()}'),
  _Case('active order, signed out', run: (s) async => 'active=${await s.hasActiveOrder()}'),
];

final _signedInCases = <_Case>[
  _Case('greeting, signed in: the turn is saved', text: 'salut', reply: _intent('greeting', message: 'Bonjour ! 😊')),
  _Case('a picture is sent with its MIME type', text: '', image: 'photo.PNG', reply: _intent('search_food', extra: {'category': 'burger'}), tables: {
    'food_items': [[_food('f14', 'Burger', venue: _venueB)]],
  }),
  _Case('a jpeg picture with a caption', text: 'c\'est quoi ?', image: 'photo.jpeg', reply: _intent('greeting', message: 'Un burger !')),
  _Case('webp, gif and unknown extensions', text: 'x', image: 'p.webp', reply: _intent('greeting', message: 'ok')),
  _Case('gif picture', text: 'x', image: 'p.gif', reply: _intent('greeting', message: 'ok')),
  _Case('unknown picture extension', text: 'x', image: 'p.heic', reply: _intent('greeting', message: 'ok')),
  _Case('a failed query persists nothing', text: 'pizza', reply: _intent('search_food', extra: {'category': 'pizza'}), tables: {'food_items': [500]}),
  _Case('colis with a saved recipient', text: 'envoyer un colis', reply: _intent('delivery_request', message: 'Pour envoyer un colis…'), tables: {
    'saved_recipients': [{'name': '  Maman '}],
  }),
  _Case('colis without a saved recipient', text: 'envoyer un colis', reply: _intent('delivery_request', message: 'Pour envoyer un colis…')),
  _Case('colis, recipient lookup fails', text: 'envoyer un colis', reply: _intent('delivery_request', message: 'Pour envoyer un colis…'), tables: {
    'saved_recipients': [500],
  }),
  _Case('tracking a restaurant order', text: 'où est ma commande', reply: _intent('track_order', message: 'Je vérifie ça !'), tables: {
    'orders': [
      [
        {'id': 'aaaa1111-0000', 'status': 'delivered', 'order_type': 'food', 'restaurant_id': 'r1', 'supermarket_id': null},
        {'id': 'bbbb2222-0000', 'status': 'preparing', 'order_type': 'food', 'restaurant_id': 'r1', 'supermarket_id': null},
      ],
    ],
    'restaurants': [{'name': 'Seven Pizza'}],
  }),
  _Case('tracking a facture picked up', text: 'ma facture ?', reply: _intent('track_order', message: 'Je regarde'), tables: {
    'orders': [
      [
        {'id': 'cccc3333-0000', 'status': 'pickedUp', 'order_type': 'facture', 'restaurant_id': null, 'supermarket_id': null},
      ],
    ],
  }),
  _Case('tracking a supermarket order on its way', text: 'commande ?', reply: _intent('track_order', message: 'Je regarde'), tables: {
    'orders': [
      [
        {'id': 'dddd4444-0000', 'status': 'onTheWay', 'order_type': 'grocery', 'restaurant_id': null, 'supermarket_id': 's9'},
      ],
    ],
    'supermarkets': [{'name': 'Monoprix'}],
  }),
  _Case('tracking: every order is finished', text: 'commande ?', reply: _intent('track_order', message: 'Je regarde'), tables: {
    'orders': [
      [
        {'id': 'eeee5555-0000', 'status': 'delivered', 'order_type': 'food', 'restaurant_id': null, 'supermarket_id': null},
        {'id': 'ffff6666-0000', 'status': 'cancelled', 'order_type': 'food', 'restaurant_id': null, 'supermarket_id': null},
      ],
    ],
  }),
  _Case('tracking: unknown status shown raw', text: 'commande ?', reply: _intent('track_order', message: 'Je regarde'), tables: {
    'orders': [
      [
        {'id': 'gggg7777-0000', 'status': 'ready', 'order_type': 'facture', 'restaurant_id': null, 'supermarket_id': null},
      ],
    ],
  }),
  _Case('tracking: venue lookup fails', text: 'commande ?', reply: _intent('track_order', message: 'Je regarde'), tables: {
    'orders': [
      [
        {'id': 'hhhh8888-0000', 'status': 'confirmed', 'order_type': 'food', 'restaurant_id': 'r1', 'supermarket_id': null},
      ],
    ],
    'restaurants': [500],
  }),
  _Case('tracking: the orders cannot be read', text: 'commande ?', reply: _intent('track_order', message: 'Je regarde'), tables: {
    'orders': [500],
  }),
  _Case('facture question with a usual bill', text: 'je veux payer ma fatoura', reply: _intent('general', message: 'Pour payer une facture…'), tables: {
    'orders': [
      [
        {'bill_type': 'sonede'},
        {'bill_type': 'steg'},
        {'bill_type': ' steg '},
        {'bill_type': ''},
      ],
    ],
  }),
  _Case('facture question, never paid one', text: 'invoice', reply: _intent('general', message: 'To pay a bill…')),
  _Case('facture question, the lookup fails', text: 'topnet bill', reply: _intent('general', message: 'Pour payer…'), tables: {'orders': [500]}),
  _Case('history, signed in', run: (s) async => (await s.loadHistory()).map(_describe).join('\n'), tables: {
    'chat_messages': [
      [
        {'text': 'Voici des pizzas', 'is_user': false, 'created_at': '2026-10-21T10:00:00Z'},
        {'text': 'pizza', 'is_user': true, 'created_at': '2026-10-21T10:00:00Z'},
        {'text': null, 'is_user': null, 'created_at': '2026-10-21T09:00:00Z'},
      ],
    ],
  }),
  _Case('history cannot be read', run: (s) async => (await s.loadHistory()).map(_describe).join('\n'), tables: {
    'chat_messages': [500],
  }),
  _Case('clear, signed in', run: (s) async => 'cleared=${await s.clearHistory()}'),
  _Case('clear fails', run: (s) async => 'cleared=${await s.clearHistory()}', tables: {'chat_messages': [500]}),
  _Case('active order, signed in', run: (s) async => 'active=${await s.hasActiveOrder()}', tables: {
    'orders': [
      [
        {'id': 'iiii9999-0000', 'status': 'pending', 'order_type': 'food', 'restaurant_id': null, 'supermarket_id': null},
      ],
    ],
  }),
  _Case('no active order, signed in', run: (s) async => 'active=${await s.hasActiveOrder()}', tables: {
    'orders': [
      [
        {'id': 'jjjj0000-0000', 'status': 'delivered', 'order_type': 'food', 'restaurant_id': null, 'supermarket_id': null},
      ],
    ],
  }),
];

Future<String> _record(_Case c, Directory tmp) async {
  _log.clear();
  _tables
    ..clear()
    ..addAll({for (final e in c.tables.entries) e.key: List<Object?>.of(e.value)});
  _fnReply = c.reply;
  _fnStatus = c.status;
  _fnNetworkDown = c.networkDown;

  final service = AiChatService();
  String result;
  if (c.run != null) {
    result = await c.run!(service);
  } else {
    File? image;
    if (c.image != null) {
      image = File('${tmp.path}/${c.image}')..writeAsBytesSync([1, 2, 3, 4, 5]);
    }
    final reply = await service.sendMessage(c.text, c.history, imageFile: image);
    result = _describe(reply);
  }
  // The turn is saved without being awaited: let it land.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return [..._log, result].join('\n');
}

void main() {
  late Directory tmp;
  final recorded = <String, String>{};
  final update = Platform.environment['AI_CHAT_GOLDEN'] == 'update';
  final golden = update || !File(_goldenPath).existsSync()
      ? <String, dynamic>{}
      : jsonDecode(File(_goldenPath).readAsStringSync()) as Map<String, dynamic>;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
      httpClient: MockClient(_handle),
    );
    tmp = Directory.systemTemp.createTempSync('ai_chat_char');
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
    if (update) {
      File(_goldenPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(
            recorded.map((k, v) => MapEntry(k, v.split('\n')))));
    }
  });

  void check(String group, _Case c) {
    test('$group: ${c.name}', () async {
      final got = await _record(c, tmp);
      recorded['$group: ${c.name}'] = got;
      if (update) return;
      final want = golden['$group: ${c.name}'];
      expect(want, isNotNull, reason: 'no golden for this case: re-record it on purpose');
      expect(got.split('\n'), want);
    });
  }

  // Signed out first: the session below is never cleared.
  for (final c in _signedOutCases) {
    check('signed out', c);
  }
  test('sign in', () async {
    await Supabase.instance.client.auth.recoverSession(_fakeSession());
    expect(Supabase.instance.client.auth.currentUser?.id, 'u1');
  });
  for (final c in _signedInCases) {
    check('signed in', c);
  }
  test('every recorded case has a golden, and no golden is stale', () {
    if (update) return;
    expect(golden.keys.toSet(), recorded.keys.toSet());
  });
}
