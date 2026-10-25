import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:cmandili_mobile/features/ai_search/data/models/search_result.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/widgets/ai_search_result_card.dart';

/// The result the phone test showed for "N7eb chapati 7arra matfoutch 10 dt":
/// a shop with no review yet (rating 0, the column default) and no dish photo.
AiSearchFoodResult _chapati({double? rating}) => AiSearchFoodResult.fromJson({
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
        'is_open': true,
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
}
