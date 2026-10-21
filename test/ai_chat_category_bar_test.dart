// Category bar under the chat header.
//
// The header row is already at its width limit (see the overflow fix in
// _buildAppBar), so the 9 services live in a horizontal scroller below it
// instead. These tests check that every service is reachable, that the bar
// cannot overflow at phone widths, and that a chip sends a real question
// rather than taking a special code path.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_mobile/core/models/service_category.dart';
import 'package:cmandili_mobile/features/ai_chat/presentation/ai_chat/ai_chat_screen.dart';

Future<void> pumpChat(WidgetTester tester, {double width = 393}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // The screen keeps its conversation in a Riverpod controller, so it needs
  // the ProviderScope the app puts at its root.
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AiChatScreen())));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
    );
  });

  group('starterQueryFor — every service sends a natural question', () {
    test('all 9 services have a distinct, non-empty starter', () {
      final seen = <String>{};
      for (final t in ServiceType.values) {
        final q = AiChatScreen.starterQueryFor(t);
        expect(q.trim(), isNotEmpty, reason: '$t has no starter');
        expect(seen.add(q), isTrue, reason: 'duplicate starter for $t: $q');
      }
      expect(seen, hasLength(ServiceType.values.length));
    });

    test('the starters read as questions a customer would type', () {
      expect(AiChatScreen.starterQueryFor(ServiceType.flowers),
          'Montre-moi les fleurs disponibles');
      expect(AiChatScreen.starterQueryFor(ServiceType.pets),
          "Montre-moi les produits d'animalerie");
      expect(AiChatScreen.starterQueryFor(ServiceType.courier),
          'Je veux envoyer un colis');
      expect(AiChatScreen.starterQueryFor(ServiceType.billPayments),
          'Je veux payer une facture');
    });
  });

  group('the bar itself', () {
    testWidgets('reaches all 9 services by scrolling', (tester) async {
      await pumpChat(tester);
      final bar = find
          .byWidgetPredicate((w) =>
              w is ListView && w.scrollDirection == Axis.horizontal)
          .first;

      // A horizontal ListView builds lazily, so the later chips do not exist
      // until scrolled to — which is the point: the bar has no width ceiling.
      for (final c in ServiceCategory.categories) {
        await tester.scrollUntilVisible(find.text(c.nameFr), 120,
            scrollable: find.descendant(
                of: bar, matching: find.byType(Scrollable)));
        expect(find.text(c.nameFr), findsOneWidget,
            reason: '${c.nameFr} unreachable in the bar');
      }
    });

    testWidgets('includes the 5 catalogues that had no entry point before',
        (tester) async {
      await pumpChat(tester);
      final labels =
          ServiceCategory.categories.map((c) => c.nameFr).toSet();
      for (final label in [
        'Pâtisserie',
        'Fleurs',
        'Animalerie',
        'Cadeaux',
        'Électronique',
        'Colis',
        'Facture',
      ]) {
        expect(labels, contains(label));
      }
    });

    testWidgets('never overflows, at 360dp or 320dp', (tester) async {
      for (final w in <double>[320, 360, 393, 430]) {
        await pumpChat(tester, width: w);
        final exc = tester.takeException();
        final overflowed =
            exc != null && exc.toString().toLowerCase().contains('overflow');
        expect(overflowed, isFalse, reason: 'bar overflowed at ${w}dp: $exc');
      }
    });

    testWidgets('scrolls horizontally rather than wrapping', (tester) async {
      await pumpChat(tester, width: 360);
      final lists = tester
          .widgetList<ListView>(find.byType(ListView))
          .where((l) => l.scrollDirection == Axis.horizontal);
      expect(lists, isNotEmpty,
          reason: 'the bar should be a horizontal ListView');
    });

    testWidgets('tapping a chip sends that service\'s question', (tester) async {
      await pumpChat(tester);
      final bar = find
          .byWidgetPredicate((w) =>
              w is ListView && w.scrollDirection == Axis.horizontal)
          .first;
      await tester.scrollUntilVisible(find.text('Fleurs'), 120,
          scrollable:
              find.descendant(of: bar, matching: find.byType(Scrollable)));
      // scrollUntilVisible stops as soon as the widget is built, which can
      // still leave it past the right edge; ensureVisible brings it fully in.
      // (No pumpAndSettle anywhere here: the typing indicator's
      // AnimationController repeats forever and would never settle.)
      await tester.ensureVisible(find.text('Fleurs'));
      await tester.pump();
      await tester.tap(find.text('Fleurs'));
      await tester.pump();

      // The question is submitted like any typed message, so it shows up as
      // the user's own bubble.
      expect(find.text('Montre-moi les fleurs disponibles'), findsWidgets);

      // The send starts a real request, whose 60s client timeout would be
      // left pending and fail teardown. Advance past it so the timer fires
      // and the service settles on its network-error reply.
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
    });
  });

  group('the header is left alone', () {
    testWidgets('the bar lives below the header, not inside it',
        (tester) async {
      await pumpChat(tester);
      // The whole reason the bar exists outside the AppBar: the header row is
      // at its width limit, so chips up there would reintroduce the overflow.
      final inHeader = find.descendant(
        of: find.byType(PreferredSize),
        matching: find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal),
      );
      expect(inHeader, findsNothing);
      expect(find.text('Amana Assistant'), findsOneWidget);
    });
  });
}
