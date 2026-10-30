// Phone test, 30/10/2026: "Commander" at Charlot failed with
//   insert or update on table "order_items" violates foreign key constraint
//   "order_items_food_item_id_fkey" ... not present in table "food_items_legacy"
// and the order stayed 'pending' with no item. The database side is fixed in
// 20261030120000_order_items_legacy_mirror.sql (tested on live in
// supabase/tests/order_items_legacy_mirror_test.sql). Here: each shop type
// writes its line in its own column, and a line the database refuses cancels
// the order instead of leaving it empty in the partner's queue.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/core/models/vendor.dart';
import 'package:cmandili_mobile/features/cart/data/models/cart_item.dart';
import 'package:cmandili_mobile/features/checkout/data/models/delivery_address.dart';
import 'package:cmandili_mobile/features/orders/data/models/order.dart';
import 'package:cmandili_mobile/features/orders/data/order_placement_repository.dart';
import 'package:cmandili_mobile/features/restaurant/data/models/food_item.dart';
import 'package:cmandili_mobile/features/supermarket/data/models/grocery_category.dart';
import 'package:cmandili_mobile/features/supermarket/data/models/grocery_item.dart';

final _requests = <({String method, String table, String query, Object? body})>[];
var _orderSeq = 0;

/// Item ids the fake database refuses, like live refused Charlot's dishes.
final _refused = <String>{};

String _b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

String _session() => jsonEncode({
      'access_token': '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
          '${_b64({'sub': 'u1', 'exp': 4102444800, 'role': 'authenticated'})}.c2ln',
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

http.Response _json(Object? body, int status, http.BaseRequest req) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}, request: req);

Future<http.Response> _handle(http.Request req) async {
  final table = req.url.path.split('/').last;
  final body = req.body.isEmpty ? null : jsonDecode(req.body);
  _requests.add((method: req.method, table: table, query: Uri.decodeQueryComponent(req.url.query), body: body));
  if (req.method == 'POST' && table == 'orders') {
    _orderSeq++;
    return _json({
      'id': 'o-$_orderSeq',
      'delivery_fee': 3.5,
      'total': 15.5,
      'loyalty_milestone_type': null,
      'loyalty_discount_amount': 0,
    }, 201, req);
  }
  if (req.method == 'POST' && table == 'order_items') {
    final line = (body is List ? body.first : body) as Map<String, dynamic>;
    final ids = [line['food_item_id'], line['grocery_item_id'], line['vendor_item_id']];
    if (ids.any(_refused.contains)) {
      return _json({
        'code': '23503',
        'message': 'insert or update on table "order_items" violates foreign key constraint '
            '"order_items_food_item_id_fkey"',
        'details': 'Key is not present in table "food_items_legacy".',
      }, 409, req);
    }
    return http.Response('', 201, request: req);
  }
  return _json([], 200, req);
}

final _address = DeliveryAddress(
  id: 'a1',
  label: 'Maison',
  fullAddress: 'M4F4+FV4, Kairouan',
  latitude: 35.67,
  longitude: 10.1,
);

final _dish = FoodItem(
  id: 'charlot-dish',
  restaurantId: 'charlot',
  name: 'Sandwich Thon',
  description: '',
  imageUrl: '',
  price: 3.5,
  category: 'Sandwiches',
);

const _product = GroceryItem(
  id: 'monoprix-product',
  supermarketId: 'monoprix',
  name: 'Lait 1 L',
  description: '',
  imageUrl: '',
  price: 2.1,
  category: GroceryCategory.dairy,
  unit: 'L',
);

const _cake = VendorItem(
  id: 'bakery-cake',
  vendorId: 'delices',
  name: 'Gâteau chocolat',
  description: '',
  imageUrl: '',
  price: 78,
);

Future<String> _order(CartItem line, {String? restaurantId, String? supermarketId, OrderType type = OrderType.food}) async {
  final created = await OrderPlacementRepository().createOrder(
    items: [line],
    deliveryAddress: _address,
    subtotal: 12,
    deliveryFee: 3.5,
    total: 15.5,
    orderType: type,
    restaurantId: restaurantId,
    supermarketId: supermarketId,
  );
  return created.orderId;
}

Map<String, dynamic> _onlyLine() {
  final lines = _requests.where((r) => r.method == 'POST' && r.table == 'order_items').toList();
  expect(lines, hasLength(1));
  final body = lines.single.body;
  return (body is List ? body.first : body) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
      httpClient: MockClient(_handle),
    );
    await Supabase.instance.client.auth.recoverSession(_session());
  });

  setUp(() {
    _requests.clear();
    _refused.clear();
  });

  test('restaurant: the dish goes in food_item_id, nothing else', () async {
    await _order(CartItem.restaurant(foodItem: _dish), restaurantId: 'charlot');
    final line = _onlyLine();
    expect(line['food_item_id'], 'charlot-dish');
    expect(line['grocery_item_id'], isNull);
    expect(line['vendor_item_id'], isNull);
  });

  test('supermarket: the product goes in grocery_item_id, nothing else', () async {
    await _order(CartItem.grocery(groceryItem: _product), supermarketId: 'monoprix', type: OrderType.grocery);
    final line = _onlyLine();
    expect(line['grocery_item_id'], 'monoprix-product');
    expect(line['food_item_id'], isNull);
    expect(line['vendor_item_id'], isNull);
  });

  test('boutique: the product goes in vendor_item_id, nothing else', () async {
    await _order(CartItem.vendor(vendorItem: _cake), restaurantId: 'delices', type: OrderType.bakery);
    final line = _onlyLine();
    expect(line['vendor_item_id'], 'bakery-cake');
    expect(line['food_item_id'], isNull);
    expect(line['grocery_item_id'], isNull);
    expect(_requests.where((r) => r.method == 'PATCH'), isEmpty);
  });

  test('a line the database refuses cancels the order and keeps the error', () async {
    _refused.add('charlot-dish');
    await expectLater(
      _order(CartItem.restaurant(foodItem: _dish), restaurantId: 'charlot'),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23503')),
    );
    final created = _requests.firstWhere((r) => r.method == 'POST' && r.table == 'orders');
    expect(created.body, isNotNull);
    final cancel = _requests.where((r) => r.method == 'PATCH' && r.table == 'orders').toList();
    expect(cancel, hasLength(1));
    expect(cancel.single.query, contains('id=eq.o-$_orderSeq'));
    final patch = cancel.single.body as Map<String, dynamic>;
    expect(patch['status'], 'cancelled');
    expect(patch['cancelled_by'], 'system');
  });
}
