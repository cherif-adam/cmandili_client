// AI search with closed shops: they are listed after the open ones (the
// ai-search function orders them), dimmed with « Fermé » like on the home
// screen, and when every matching shop is closed the screen says so above the
// list instead of "nothing matches".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/features/ai_search/data/ai_search_repository.dart';
import 'package:cmandili_mobile/features/ai_search/data/models/search_result.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/ai_search_screen.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/widgets/ai_search_result_card.dart';
import 'package:cmandili_mobile/features/ai_search/providers/ai_search_provider.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

const _allClosed = 'Ces restaurants sont fermés pour le moment';

AiSearchFoodResult _dish(String id, String shop, {required bool open}) => AiSearchFoodResult.fromJson({
      'id': id,
      'name': 'Chapati $id',
      'description': '',
      'price': 4,
      'image_url': null,
      'category': 'Chapati',
      'is_spicy': false,
      'is_vegetarian': false,
      'preparation_time': 10,
      'restaurant_id': shop,
      'restaurants': {'id': shop, 'name': shop, 'rating': 0, 'is_open': open},
    });

AiSearchState _textResults(List<AiSearchFoodResult> results) => AiSearchState(
      mode: AiSearchMode.text,
      textResponse: AiTextSearchResponse(
        intent: const TextSearchIntent(keyword: 'chapati', maxPrice: 10),
        results: results,
      ),
    );

/// The screen's notifier, already holding a search answer.
class _Answered extends AiSearchNotifier {
  _Answered(AiSearchState answer) : super(AiSearchRepository()) {
    state = answer;
  }
}

Future<void> _pumpScreen(WidgetTester tester, AiSearchState answer) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
}

List<String> _cardIds(WidgetTester tester) =>
    tester.widgetList<AiSearchResultCard>(find.byType(AiSearchResultCard)).map((c) => c.item.id).toList();

void main() {
  final mix = [
    _dish('planb-1', 'plan b', open: true),
    _dish('seven-1', 'Seven pizza', open: true),
    _dish('nuit-1', 'Chez Nuit', open: false),
  ];
  final allClosed = [
    _dish('nuit-1', 'Chez Nuit', open: false),
    _dish('midi-1', 'Midi', open: false),
  ];

  group('AiSearchState.allShopsClosed', () {
    test('open + closed: false', () => expect(_textResults(mix).allShopsClosed, isFalse));
    test('all closed: true', () => expect(_textResults(allClosed).allShopsClosed, isTrue));
    test('no result: false (the screen says "nothing matches" instead)',
        () => expect(_textResults(const []).allShopsClosed, isFalse));
  });

  testWidgets('open + closed: no notice, open shops first, the closed one dimmed', (tester) async {
    await _pumpScreen(tester, _textResults(mix));
    expect(find.text(_allClosed), findsNothing);
    expect(_cardIds(tester), ['planb-1', 'seven-1', 'nuit-1']);
    expect(find.text('Fermé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all closed: the dishes are shown, under "Ces restaurants sont fermés"', (tester) async {
    await _pumpScreen(tester, _textResults(allClosed));
    expect(find.text(_allClosed), findsOneWidget);
    expect(find.text('Aucun plat ne correspond à ta demande'), findsNothing);
    expect(_cardIds(tester), ['nuit-1', 'midi-1']);
    expect(find.text('Fermé'), findsNWidgets(2));
    // The notice sits above the list.
    expect(
      tester.getTopLeft(find.text(_allClosed)).dy,
      lessThan(tester.getTopLeft(find.byType(AiSearchResultCard).first).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
