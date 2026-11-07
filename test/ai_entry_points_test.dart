// AI entry points of the home screen — widgets (2026-11-06).
//
// The search field (typewriter, ✦, "Nouveau", keyboard action), the empty
// restaurant list's "Chercher « … » avec l'IA" row, the assistant button
// (extended/collapsed, teaser), the one-time coach mark, and reduced motion.
// The rules themselves are in test/ai_onboarding_controller_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cmandili_mobile/features/ai_onboarding/data/ai_onboarding_store.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/ai_onboarding_controller.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/widgets/ai_onboarding_host.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/widgets/ai_pulse_halo.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/widgets/ai_shimmer_border.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/widgets/living_ai_icon.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/widgets/twinkling_sparkle.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/widgets/typewriter_hint.dart';
import 'package:cmandili_mobile/features/ai_search/data/ai_search_repository.dart';
import 'package:cmandili_mobile/features/ai_search/data/models/search_result.dart';
import 'package:cmandili_mobile/features/ai_search/presentation/ai_search/ai_search_screen.dart';
import 'package:cmandili_mobile/features/ai_search/providers/ai_search_provider.dart';
import 'package:cmandili_mobile/features/home/presentation/home/widgets/ai_chat_fab.dart';
import 'package:cmandili_mobile/features/home/presentation/home_tab/widgets/home_search_field.dart';
import 'package:cmandili_mobile/features/home/presentation/home_tab/widgets/restaurant_list_sliver.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

const _staticHint = "Un restaurant, un plat… ou demande à l'IA";
const _focusedHint = 'Rechercher des restaurants...';
const _phrase1 = 'Essaie : pizza moins de 15 DT...';
const _phrase2 = 'Un plat léger pour ce soir...';
const _coachTitle1 = "Nouveau ✦ Cherche avec l'IA";
const _coachTitle2 = 'Amana Assistant';
const _askAmana = 'Demande à Amana';
const _middayTeaser = "Tu as faim ? Je t'aide à choisir 🍕";

/// Plays AI search states; records the text a search was asked for instead
/// of calling the Edge Function.
class _FakeSearch extends AiSearchNotifier {
  _FakeSearch() : super(AiSearchRepository());

  String? lastQuery;

  void emit(AiSearchState next) => state = next;

  @override
  Future<void> searchByText(String query) async => lastQuery = query;
}

late _FakeSearch _search;

List<Override> _overrides({DateTime Function()? clock}) => [
      aiSearchProvider.overrideWith((ref) => _search = _FakeSearch()),
      aiHomeDataLoadedProvider.overrideWith((ref) => true),
      if (clock != null) aiOnboardingClockProvider.overrideWithValue(clock),
    ];

/// Advances [total] in 50 ms frames, like a phone drawing every frame. One
/// big `pump(duration)` jumps the clock in a single frame: an animation then
/// ends at once and anything chained on it starts from its beginning.
Future<void> _advance(WidgetTester tester, Duration total) async {
  const frame = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(frame);
    elapsed += frame;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  bool reduceMotion = false,
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(clock: clock),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: reduceMotion
          ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
          : null,
      home: home,
    ),
  ));
  // SharedPreferences answers on the next microtasks.
  await tester.pump();
  await tester.pump();
}

/// The search field as the home header places it.
class _SearchFieldPage extends StatefulWidget {
  const _SearchFieldPage();

  @override
  State<_SearchFieldPage> createState() => _SearchFieldPageState();
}

class _SearchFieldPageState extends State<_SearchFieldPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Column(
      children: [
        const SizedBox(height: 60),
        HomeSearchField(
          controller: _controller,
          query: _controller.text.toLowerCase(),
          onChanged: (_) => setState(() {}),
          onCleared: () => setState(_controller.clear),
          screenWidth: size.width,
          screenHeight: size.height,
        ),
      ],
    );
  }
}

/// A home screen with both entry points under the onboarding host.
Widget _home() => const AiOnboardingHost(
      onHomeTab: true,
      child: Scaffold(
        body: _SearchFieldPage(),
        floatingActionButton: AiChatFab(),
      ),
    );

/// A long list, to scroll the assistant button closed and open.
Widget _scrollingHome() => AiOnboardingHost(
      onHomeTab: true,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => SizedBox(height: 80, child: Text('row $i')),
                childCount: 60,
              ),
            ),
          ],
        ),
        floatingActionButton: const AiChatFab(),
      ),
    );

/// Seen, many sessions in, teaser spent: nothing but the subtle motion.
const _quietUser = {
  AiOnboardingStore.kOnboardingSeen: true,
  AiOnboardingStore.kSessionCount: 9,
  AiOnboardingStore.kChatOpenCount: 3,
};

void main() {
  group('search field', () {
    testWidgets('the "Nouveau" badge disappears after the first AI search', (tester) async {
      SharedPreferences.setMockInitialValues(_quietUser);
      await _pump(tester, const Scaffold(body: _SearchFieldPage()));
      expect(find.text('Nouveau'), findsOneWidget);

      _search.emit(const AiSearchState(mode: AiSearchMode.text, isLoading: true));
      _search.emit(const AiSearchState(
        mode: AiSearchMode.text,
        textResponse: AiTextSearchResponse(
          intent: TextSearchIntent(keyword: 'calzone'),
          results: [],
          status: AiSearchStatus.noMatch,
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Nouveau'), findsNothing);
      expect(find.byType(TwinklingSparkle), findsOneWidget, reason: 'the ✦ stays');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AiOnboardingStore.kFirstSearchDone), isTrue);
    });

    testWidgets('the placeholder types the examples, then stops on focus', (tester) async {
      SharedPreferences.setMockInitialValues(_quietUser);
      await _pump(tester, const Scaffold(body: _SearchFieldPage()));

      expect(find.byType(TypewriterHint), findsOneWidget);
      await _advance(tester, const Duration(milliseconds: 500));
      final partial = tester.widget<Text>(find.descendant(
        of: find.byType(TypewriterHint),
        matching: find.byType(Text),
      ));
      expect(_phrase1.startsWith(partial.data!), isTrue);
      expect(partial.data!.length, lessThan(_phrase1.length), reason: 'letter by letter');

      await _advance(tester, const Duration(milliseconds: 2500));
      expect(find.text(_phrase1), findsOneWidget, reason: 'typed in full, then held');
      await _advance(tester, const Duration(milliseconds: 6000));
      expect(find.text(_phrase2), findsOneWidget, reason: 'erased, then the next one');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.byType(TypewriterHint), findsNothing);
      expect(find.text(_focusedHint), findsOneWidget);
    });

    testWidgets('keyboard "Rechercher" opens Recherche IA with the text searched',
        (tester) async {
      SharedPreferences.setMockInitialValues(_quietUser);
      await _pump(tester, const Scaffold(body: _SearchFieldPage()));

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'pizza moins de 15 DT');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AiSearchScreen), findsOneWidget);
      expect(_search.lastQuery, 'pizza moins de 15 DT');
    });
  });

  group('empty restaurant list', () {
    Widget list({required String query, required String text}) => Scaffold(
          body: Builder(builder: (context) {
            final size = MediaQuery.sizeOf(context);
            return CustomScrollView(slivers: [
              RestaurantListSliver(
                restaurants: const AsyncValue.data([]),
                selectedCategory: 'All',
                searchQuery: query,
                searchText: text,
                screenWidth: size.width,
                screenHeight: size.height,
              ),
            ]);
          }),
        );

    testWidgets('typed text that matches no restaurant: "Chercher « … » avec l\'IA ✦" '
        'opens Recherche IA with it', (tester) async {
      SharedPreferences.setMockInitialValues(_quietUser);
      await _pump(tester, list(query: 'calzone', text: 'Calzone'));

      final row = find.text("Chercher « Calzone » avec l'IA ✦");
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AiSearchScreen), findsOneWidget);
      expect(_search.lastQuery, 'Calzone');
    });

    testWidgets('nothing typed: no AI row', (tester) async {
      SharedPreferences.setMockInitialValues(_quietUser);
      await _pump(tester, list(query: '', text: ''));
      expect(find.textContaining('avec l\'IA'), findsNothing);
    });
  });

  group('reduced motion', () {
    testWidgets('fixed placeholder, nothing moves, nothing keeps running', (tester) async {
      // First session: shimmer and pulse would play without reduced motion.
      SharedPreferences.setMockInitialValues({
        AiOnboardingStore.kOnboardingSeen: true,
        AiOnboardingStore.kChatOpenCount: 3,
      });
      await _pump(
        tester,
        const AiOnboardingHost(
          onHomeTab: true,
          child: Scaffold(body: _SearchFieldPage(), floatingActionButton: AiChatFab()),
        ),
        reduceMotion: true,
      );

      expect(find.text(_staticHint), findsOneWidget);
      expect(find.byType(TypewriterHint), findsNothing);
      expect(tester.widget<TwinklingSparkle>(find.byType(TwinklingSparkle)).animate, isFalse);
      expect(tester.widget<LivingAiIcon>(find.byType(LivingAiIcon)).animate, isFalse);
      expect(tester.widget<AiShimmerBorder>(find.byType(AiShimmerBorder)).play, isFalse);
      expect(tester.widget<AiPulseHalo>(find.byType(AiPulseHalo)).play, isFalse);
      // Settles: no repeating animation anywhere (it would time out).
      await tester.pumpAndSettle();
    });

    testWidgets('without it, the first sessions get the shimmer, the pulse and the '
        'typewriter', (tester) async {
      SharedPreferences.setMockInitialValues({
        AiOnboardingStore.kOnboardingSeen: true,
        AiOnboardingStore.kChatOpenCount: 3,
      });
      await _pump(
        tester,
        const AiOnboardingHost(
          onHomeTab: true,
          child: Scaffold(body: _SearchFieldPage(), floatingActionButton: AiChatFab()),
        ),
      );
      expect(find.byType(TypewriterHint), findsOneWidget);
      expect(tester.widget<AiShimmerBorder>(find.byType(AiShimmerBorder)).play, isTrue);
      expect(tester.widget<AiPulseHalo>(find.byType(AiPulseHalo)).play, isTrue);
      expect(tester.widget<LivingAiIcon>(find.byType(LivingAiIcon)).animate, isTrue);

      // Both play once, then stay off for the rest of the session.
      await tester.pump(const Duration(seconds: 6));
      expect(tester.widget<AiShimmerBorder>(find.byType(AiShimmerBorder)).play, isFalse);
      expect(tester.widget<AiPulseHalo>(find.byType(AiPulseHalo)).play, isFalse);
    });
  });

  group('coach mark', () {
    Future<void> waitForTooltip(WidgetTester tester) =>
        _advance(tester, const Duration(milliseconds: 1300));

    testWidgets('shows once after the data loaded: Suivant, Compris, never again',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, _home());
      await waitForTooltip(tester);

      expect(find.text(_coachTitle1), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);
      await tester.tap(find.text('Suivant'));
      await waitForTooltip(tester);

      expect(find.text(_coachTitle2), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);
      await tester.tap(find.text('Compris'));
      await waitForTooltip(tester);

      expect(find.text(_coachTitle2), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AiOnboardingStore.kOnboardingSeen), isTrue);

      // Next launch: a fresh app, same phone.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _home());
      await waitForTooltip(tester);
      expect(find.text(_coachTitle1), findsNothing);
    });

    testWidgets('"Passer" ends it and saves the flag too', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, _home());
      await waitForTooltip(tester);

      await tester.tap(find.text('Passer'));
      await waitForTooltip(tester);
      expect(find.text(_coachTitle1), findsNothing);
      expect(find.text(_coachTitle2), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AiOnboardingStore.kOnboardingSeen), isTrue);
    });

    testWidgets('not while the home data is loading', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          aiSearchProvider.overrideWith((ref) => _FakeSearch()),
          aiHomeDataLoadedProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _home(),
        ),
      ));
      await tester.pump();
      await waitForTooltip(tester);
      expect(find.text(_coachTitle1), findsNothing);
    });
  });

  group('assistant button', () {
    testWidgets('collapses when the list scrolls down, extends back at the top',
        (tester) async {
      SharedPreferences.setMockInitialValues(_quietUser);
      await _pump(tester, _scrollingHome());
      expect(find.text(_askAmana), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_askAmana), findsNothing, reason: 'scrolled down');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_askAmana), findsNothing, reason: 'going up, not at the top');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(_askAmana), findsOneWidget, reason: 'back at the top');
    });

    testWidgets('teaser: about 5 s after the home settles, gone after ~6 s', (tester) async {
      SharedPreferences.setMockInitialValues({
        AiOnboardingStore.kOnboardingSeen: true,
        AiOnboardingStore.kSessionCount: 9,
      });
      await _pump(tester, _home(), clock: () => DateTime(2026, 11, 6, 12, 30));

      await tester.pump(const Duration(seconds: 4));
      expect(find.text(_middayTeaser), findsNothing);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_middayTeaser), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiOnboardingStore.kLastTeaserDay), '2026-11-06');

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_middayTeaser), findsNothing);
    });

    testWidgets('teaser: the ✕ closes it', (tester) async {
      SharedPreferences.setMockInitialValues({
        AiOnboardingStore.kOnboardingSeen: true,
        AiOnboardingStore.kSessionCount: 9,
      });
      await _pump(tester, _home(), clock: () => DateTime(2026, 11, 6, 20, 0));
      await tester.pump(const Duration(milliseconds: 5300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Une idée pour ce soir ? Demande-moi 🌙"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.text("Une idée pour ce soir ? Demande-moi 🌙"), findsNothing);
    });

    testWidgets('teaser: never once the chat was opened 3 times', (tester) async {
      SharedPreferences.setMockInitialValues(_quietUser);
      await _pump(tester, _home(), clock: () => DateTime(2026, 11, 6, 12, 30));
      await tester.pump(const Duration(seconds: 7));
      expect(find.text(_middayTeaser), findsNothing);
    });
  });
}
