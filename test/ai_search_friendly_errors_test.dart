// Recherche IA never shows a raw error (2026-11-06).
//
// When Gemini answered 429, ai-search returned HTTP 502 with Gemini's whole
// error JSON, and the screen printed FunctionException.toString(). Now:
//   - any failure is classified into network / unavailable / image too large,
//     and the screen words each one itself;
//   - "no_match" says the dish is not available, in a calm empty state;
//   - "degraded" (found without AI) shows the results with a small note, and
//     "degraded" with nothing found says the smart search is unavailable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/features/ai_search/data/ai_search_repository.dart';
import 'package:cmandili_mobile/features/ai_search/data/models/search_result.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/ai_search_screen.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/widgets/ai_search_result_card.dart';
import 'package:cmandili_mobile/features/ai_search/providers/ai_search_provider.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

const _unavailable =
    'La recherche intelligente est momentanément indisponible. Réessayez dans quelques instants.';
const _noMatch =
    "Ce plat n'est pas disponible pour le moment. Essayez un autre plat ou un autre restaurant.";
const _degradedNote =
    'Résultats simplifiés : la recherche intelligente est momentanément indisponible.';

AiSearchFoodResult _dish(String id) => AiSearchFoodResult.fromJson({
      'id': id,
      'name': 'Calzone $id',
      'description': '',
      'price': 18,
      'image_url': null,
      'category': 'Sandwiches',
      'is_spicy': false,
      'is_vegetarian': false,
      'preparation_time': 10,
      'restaurant_id': 'texas',
      'restaurants': {'id': 'texas', 'name': 'Texas food', 'rating': 0, 'is_open': true},
    });

AiSearchState _text(List<AiSearchFoodResult> results, AiSearchStatus status) => AiSearchState(
      mode: AiSearchMode.text,
      textResponse: AiTextSearchResponse(
        intent: const TextSearchIntent(keyword: 'calzone'),
        results: results,
        status: status,
      ),
    );

class _Answered extends AiSearchNotifier {
  _Answered(AiSearchState answer) : super(AiSearchRepository()) {
    state = answer;
  }
}

Future<void> _pump(WidgetTester tester, AiSearchState answer) async {
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

void main() {
  group('classifyError — nothing raw survives', () {
    test('a FunctionException (the 502 with Gemini\'s JSON) is "unavailable"', () {
      const e = FunctionException(
        status: 502,
        details: {'error': 'Failed to parse AI response.', 'details': 'Gemini API error 429: {...}'},
      );
      expect(AiSearchNotifier.classifyError(e), AiSearchErrorKind.unavailable);
    });

    test('anything unknown is "unavailable" too', () {
      expect(AiSearchNotifier.classifyError(Exception('boom')), AiSearchErrorKind.unavailable);
      expect(AiSearchNotifier.classifyError(const AiSearchUnavailableException()),
          AiSearchErrorKind.unavailable);
    });

    test('no connection is "network", a big photo is "imageTooLarge"', () {
      expect(AiSearchNotifier.classifyError(const AiSearchNetworkException()),
          AiSearchErrorKind.network);
      expect(AiSearchNotifier.classifyError(const SocketException('down')),
          AiSearchErrorKind.network);
      expect(AiSearchNotifier.classifyError(const AiImageTooLargeException(12)),
          AiSearchErrorKind.imageTooLarge);
    });
  });

  group('AiSearchStatus.parse', () {
    test('reads the three statuses', () {
      expect(AiSearchStatus.parse('ok', hasResults: true), AiSearchStatus.ok);
      expect(AiSearchStatus.parse('no_match', hasResults: false), AiSearchStatus.noMatch);
      expect(AiSearchStatus.parse('degraded', hasResults: true), AiSearchStatus.degraded);
    });

    test('an older function without status: empty means no match', () {
      expect(AiSearchStatus.parse(null, hasResults: false), AiSearchStatus.noMatch);
      expect(AiSearchStatus.parse(null, hasResults: true), AiSearchStatus.ok);
    });
  });

  testWidgets('unavailable: our sentence, a retry, no red block, no raw text', (tester) async {
    await _pump(
      tester,
      const AiSearchState(mode: AiSearchMode.text, errorKind: AiSearchErrorKind.unavailable),
    );
    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no_match: "Ce plat n\'est pas disponible…" as an empty state', (tester) async {
    await _pump(tester, _text(const [], AiSearchStatus.noMatch));
    expect(find.text(_noMatch), findsOneWidget);
    expect(find.byType(AiSearchResultCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('degraded with results: shown normally, with the small note', (tester) async {
    await _pump(tester, _text([_dish('1'), _dish('2')], AiSearchStatus.degraded));
    expect(find.byType(AiSearchResultCard), findsNWidgets(2));
    expect(find.text(_degradedNote), findsOneWidget);
    expect(find.text(_unavailable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('degraded with nothing: "momentanément indisponible", not "pas disponible"',
      (tester) async {
    await _pump(tester, _text(const [], AiSearchStatus.degraded));
    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text(_noMatch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ok: no note', (tester) async {
    await _pump(tester, _text([_dish('1')], AiSearchStatus.ok));
    expect(find.byType(AiSearchResultCard), findsOneWidget);
    expect(find.text(_degradedNote), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
