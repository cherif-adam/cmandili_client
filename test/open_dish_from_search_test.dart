// A tap on an AI search result opens the dish's restaurant page, scrolled to
// the dish, which glows a moment. The restaurant is read fresh from the
// database: a closed one opens closed (its page blocks the cart), with its
// real minimum order. A chat product card does the same on its shop's page.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/core/models/vendor.dart';
import 'package:cmandili_mobile/core/widgets/dish_spotlight.dart';
import 'package:cmandili_mobile/features/ai_search/data/ai_search_repository.dart';
import 'package:cmandili_mobile/features/ai_search/data/models/search_result.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/ai_search_screen.dart';
import 'package:cmandili_mobile/features/ai_search/providers/ai_search_provider.dart';
import 'package:cmandili_mobile/features/restaurant/presentation/restaurant_detail/restaurant_detail_screen.dart';
import 'package:cmandili_mobile/features/vendors/presentation/vendor_detail/vendor_detail_screen.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

const _restaurantId = 'charlot';
const _vendorId = 'delices';

/// Charlot, closed, minimum order 15 DT: what the database says.
Map<String, dynamic> _restaurantRow() => {
      'id': _restaurantId,
      'name': 'Charlot',
      'description': 'Burgers et kabeb',
      'image_url': '',
      'rating': 0,
      'review_count': 0,
      'delivery_time_min': 30,
      'delivery_fee': 0,
      'min_order': 15,
      'categories': ['Burgers'],
      'is_open': false,
      'latitude': 35.67,
      'longitude': 10.1,
      'opening_time': '18:00',
      'created_at': '2026-09-25T18:21:57Z',
    };

/// A long menu: dish 24 is far below the first screen.
List<Map<String, dynamic>> _menuRows() => [
      for (var i = 1; i <= 30; i++)
        {
          'id': 'dish-$i',
          'restaurant_id': _restaurantId,
          'name': 'Plat $i',
          'description': '',
          'image_url': '',
          'price': 10 + i,
          'category': 'Burgers',
          'is_available': true,
          'preparation_time': 15,
          'is_vegetarian': false,
          'is_spicy': false,
          'discount_price': null,
          'discount_end_time': null,
          'created_at': '2026-09-25T18:21:57Z',
        },
    ];

List<Map<String, dynamic>> _vendorItemRows() => [
      for (var i = 1; i <= 25; i++)
        {
          'id': 'cake-$i',
          'vendor_id': _vendorId,
          'name': 'Gâteau $i',
          'description': '',
          'image_url': '',
          'price': 20 + i,
          'category': 'Gâteaux',
          'is_available': true,
          'sort_order': i,
        },
    ];

http.Response _json(Object body, http.BaseRequest req) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: req,
    );

Future<http.Response> _handle(http.Request req) async {
  final table = req.url.pathSegments.last;
  if (table == 'restaurants') {
    final single = (req.headers['Accept'] ?? req.headers['accept'] ?? '').contains('vnd.pgrst.object');
    return _json(single ? _restaurantRow() : [_restaurantRow()], req);
  }
  if (table == 'food_items') return _json(_menuRows(), req);
  if (table == 'vendor_items') return _json(_vendorItemRows(), req);
  return _json([], req);
}

AiSearchFoodResult _result(String id, String name, String shop, {required bool open}) =>
    AiSearchFoodResult.fromJson({
      'id': id,
      'name': name,
      'description': '',
      'price': 34,
      'image_url': null,
      'category': 'Burgers',
      'is_spicy': false,
      'is_vegetarian': false,
      'preparation_time': 15,
      'restaurant_id': shop,
      'restaurants': {'id': shop, 'name': shop, 'rating': 0, 'is_open': open},
    });

/// The screen's notifier, already holding a search answer.
class _Answered extends AiSearchNotifier {
  _Answered(AiSearchState answer) : super(AiSearchRepository()) {
    state = answer;
  }
}

bool _lit(WidgetTester tester) {
  final frames = find.byType(SpotlightFrame);
  return frames.evaluate().isNotEmpty && tester.widget<SpotlightFrame>(frames.first).lit.value;
}

/// Frames until the spotlit dish glows (or a generous bound). The AI search
/// screen's shimmer never stops, so pumpAndSettle cannot be used.
Future<void> _pumpUntilLit(WidgetTester tester) async {
  for (var i = 0; i < 60 && !_lit(tester); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpPastGlow(WidgetTester tester) async {
  await tester.pump(DishSpotlight.glow);
  await tester.pump(const Duration(milliseconds: 400));
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
  });

  setUp(() {
    // Wide like the other screen tests (the test font's glyphs are full
    // squares), short enough that the dish starts well below the first screen.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(800, 1000);
    view.devicePixelRatio = 1;
  });

  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('AI search: a closed restaurant\'s dish opens its page, closed, at the dish', (tester) async {
    final answer = AiSearchState(
      mode: AiSearchMode.text,
      textResponse: AiTextSearchResponse(
        intent: const TextSearchIntent(keyword: 'burger'),
        results: [
          _result('planb-1', 'Burger plan b', 'plan b', open: true),
          _result('dish-24', 'Plat 24', _restaurantId, open: false),
        ],
      ),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [aiSearchProvider.overrideWith((ref) => _Answered(answer))],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiSearchScreen(),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Plat 24'));
    await _pumpUntilLit(tester);

    final page = tester.widget<RestaurantDetailScreen>(find.byType(RestaurantDetailScreen));
    // The real row: closed (the page blocks the cart) and its own minimum
    // order, not a stand-in built from the search result.
    expect(page.restaurant.isOpen, isFalse);
    expect(page.restaurant.minimumOrder, 15);
    expect(page.highlightItemId, 'dish-24');

    expect(_lit(tester), isTrue);
    final dish = find.descendant(of: find.byType(RestaurantDetailScreen), matching: find.text('Plat 24'));
    expect(dish.hitTestable(), findsOneWidget, reason: 'scrolled into view');
    expect(find.ancestor(of: dish, matching: find.byType(SpotlightFrame)), findsOneWidget);

    await _pumpPastGlow(tester);
    expect(_lit(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat product card: the product glows on its shop\'s page', (tester) async {
    final vendor = Vendor.fromDb({
      'id': _vendorId,
      'category': 'bakery',
      'name': 'Délices de Kairouan',
      'is_open': true,
    });
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VendorDetailScreen(vendor: vendor, highlightItemId: 'cake-20'),
      ),
    ));
    await _pumpUntilLit(tester);

    expect(_lit(tester), isTrue);
    final product = find.text('Gâteau 20');
    expect(product.hitTestable(), findsOneWidget, reason: 'scrolled into view');
    expect(find.ancestor(of: product, matching: find.byType(SpotlightFrame)), findsOneWidget);

    await _pumpPastGlow(tester);
    expect(_lit(tester), isFalse);
    expect(tester.takeException(), isNull);
  });
}
