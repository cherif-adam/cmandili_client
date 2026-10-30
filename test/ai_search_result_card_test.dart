import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/core/widgets/shop_card/closed_photo_overlay.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:cmandili_mobile/features/ai_search/data/models/search_result.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/widgets/ai_search_result_card.dart';

/// The result the phone test showed for "N7eb chapati 7arra matfoutch 10 dt":
/// a shop with no review yet (rating 0, the column default) and no dish photo.
AiSearchFoodResult _chapati({double? rating, bool open = true}) => AiSearchFoodResult.fromJson({
      'id': 'c1',
      'name': 'Chapati Poulet',
      'description': '',
      'price': 9,
      'image_url': null,
      'category': 'Sandwiches',
      'is_spicy': true,
      'is_vegetarian': false,
      'preparation_time': 12,
      'restaurant_id': 'r1',
      'restaurants': {
        'id': 'r1',
        'name': 'Seven pizza Kairouan',
        'image_url': null,
        'rating': rating,
        'is_open': open,
      },
    });

Future<void> _pump(WidgetTester tester, AiSearchFoodResult item) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: AiSearchResultCard(item: item)),
  ));
  await tester.pump();
}

void main() {
  testWidgets('a shop with no review yet shows no "0.0" rating', (tester) async {
    await _pump(tester, _chapati(rating: 0));
    expect(find.text('Chapati Poulet'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('no rating at all shows no star either', (tester) async {
    await _pump(tester, _chapati());
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('a rated shop still shows its rating', (tester) async {
    await _pump(tester, _chapati(rating: 4.2));
    expect(find.text('4.2'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('a closed shop\'s dish gets the home screen\'s dim and « Fermé »', (tester) async {
    await _pump(tester, _chapati(open: false));
    expect(find.text('Chapati Poulet'), findsOneWidget);
    expect(find.byType(ClosedPhotoOverlay), findsOneWidget);
    expect(find.text('Fermé'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    // The label fits the 110 px thumbnail even on this 800 px test screen.
    expect(tester.takeException(), isNull);
    // Nothing to order from: no add button, open or closed.
    expect(find.byWidgetPredicate((w) => w is ButtonStyleButton || w is IconButton), findsNothing);
  });

  testWidgets('an open shop\'s dish has no « Fermé »', (tester) async {
    await _pump(tester, _chapati());
    expect(find.byType(ClosedPhotoOverlay), findsNothing);
    expect(find.text('Fermé'), findsNothing);
  });
}
