// AI entry points — the rules of AiOnboardingController (2026-11-06).
//
// Everything that decides what the two AI entry points of the home screen
// show: sessions, the "Nouveau" badge, the strong animations of the first
// sessions, the coach mark, the teaser bubble and the collapsing assistant
// button. Pure rules first, then the controller against the
// SharedPreferences test store and a fake clock.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cmandili_mobile/features/ai_onboarding/data/ai_onboarding_store.dart';
import 'package:cmandili_mobile/features/ai_onboarding/presentation/ai_onboarding_controller.dart';
import 'package:cmandili_mobile/features/ai_search/data/ai_search_repository.dart';
import 'package:cmandili_mobile/features/ai_search/data/models/search_result.dart';
import 'package:cmandili_mobile/features/ai_search/providers/ai_search_provider.dart';

/// Lets a test play the AI search states the controller listens to.
class _FakeSearch extends AiSearchNotifier {
  _FakeSearch() : super(AiSearchRepository());
  void emit(AiSearchState next) => state = next;
}

/// A clock the test moves by hand.
class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiOnboardingRules — pure', () {
    test('time of day: before 11 h, 11–15 h, from 18 h, else other', () {
      AiTeaserMoment at(int h, int m) => AiOnboardingRules.momentFor(DateTime(2026, 11, 6, h, m));
      expect(at(0, 30), AiTeaserMoment.morning);
      expect(at(10, 59), AiTeaserMoment.morning);
      expect(at(11, 0), AiTeaserMoment.midday);
      expect(at(14, 59), AiTeaserMoment.midday);
      expect(at(15, 0), AiTeaserMoment.other);
      expect(at(17, 59), AiTeaserMoment.other);
      expect(at(18, 0), AiTeaserMoment.evening);
      expect(at(23, 59), AiTeaserMoment.evening);
    });

    test('day key is yyyy-MM-dd', () {
      expect(AiOnboardingRules.dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });

    test('a new session only after 30 minutes in the background', () {
      final t = DateTime(2026, 11, 6, 12);
      expect(AiOnboardingRules.isNewSession(hiddenAt: null, now: t), isFalse);
      expect(
        AiOnboardingRules.isNewSession(
            hiddenAt: t.subtract(const Duration(minutes: 29)), now: t),
        isFalse,
      );
      expect(
        AiOnboardingRules.isNewSession(
            hiddenAt: t.subtract(const Duration(minutes: 30)), now: t),
        isTrue,
      );
    });

    test('assistant button: extended at the top, collapsed going down, '
        'extended again only back at the top', () {
      bool next(bool current, double offset, double delta) =>
          AiOnboardingRules.fabExtendedAfterScroll(
              current: current, offset: offset, delta: delta);
      expect(next(true, 300, 12), isFalse, reason: 'scrolling down collapses');
      expect(next(false, 250, -12), isFalse, reason: 'scrolling up mid-list stays');
      expect(next(false, 10, -12), isTrue, reason: 'back at the top extends');
      expect(next(false, -40, -5), isTrue, reason: 'pull-to-refresh counts as top');
    });
  });

  group('AiOnboardingController', () {
    late _Clock clock;
    late _FakeSearch search;

    // One fake search per container (each container disposes its own);
    // [search] is always the latest launch's.
    ProviderContainer makeContainer() {
      final c = ProviderContainer(overrides: [
        aiOnboardingClockProvider.overrideWithValue(clock.call),
        aiSearchProvider.overrideWith((ref) => search = _FakeSearch()),
        aiHomeDataLoadedProvider.overrideWith((ref) => true),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<(ProviderContainer, AiOnboardingController)> launch() async {
      final c = makeContainer();
      final controller = c.read(aiOnboardingControllerProvider.notifier);
      await controller.ready;
      return (c, controller);
    }

    AiOnboardingState stateOf(ProviderContainer c) => c.read(aiOnboardingControllerProvider);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      clock = _Clock(DateTime(2026, 11, 6, 12, 30));
    });

    test('each launch is a session, counted in SharedPreferences', () async {
      var (c, _) = await launch();
      expect(stateOf(c).sessionCount, 1);
      (c, _) = await launch();
      expect(stateOf(c).sessionCount, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AiOnboardingStore.kSessionCount), 2);
    });

    test('strong animations: sessions 1 to 5 only', () async {
      SharedPreferences.setMockInitialValues({AiOnboardingStore.kSessionCount: 4});
      var (c, _) = await launch(); // session 5
      expect(AiOnboardingRules.strongAnimationsAllowed(stateOf(c)), isTrue);
      (c, _) = await launch(); // session 6
      expect(AiOnboardingRules.strongAnimationsAllowed(stateOf(c)), isFalse);
    });

    test('back after 30 min in the background: a new session, the moments may '
        'play again; back after 10 min: same session', () async {
      final (c, controller) = await launch();
      controller.markShimmerPlayed();
      controller.markPulsePlayed();

      controller.onAppHidden(clock.now);
      await controller.onAppShown(clock.now.add(const Duration(minutes: 10)));
      expect(stateOf(c).sessionCount, 1);
      expect(stateOf(c).shimmerPlayed, isTrue);

      controller.onAppHidden(clock.now);
      await controller.onAppShown(clock.now.add(const Duration(minutes: 31)));
      expect(stateOf(c).sessionCount, 2);
      expect(stateOf(c).shimmerPlayed, isFalse);
      expect(stateOf(c).pulsePlayed, isFalse);
    });

    test('the "Nouveau" badge goes away for good after the first AI search', () async {
      var (c, _) = await launch();
      expect(stateOf(c).showNewBadge, isTrue);

      search.emit(const AiSearchState(mode: AiSearchMode.text, isLoading: true));
      expect(stateOf(c).showNewBadge, isTrue, reason: 'a search still running');
      search.emit(const AiSearchState(
        mode: AiSearchMode.text,
        textResponse: AiTextSearchResponse(
          intent: TextSearchIntent(keyword: 'calzone'),
          results: [],
          status: AiSearchStatus.noMatch,
        ),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(c).showNewBadge, isFalse);

      (c, _) = await launch();
      expect(stateOf(c).showNewBadge, isFalse, reason: 'remembered across launches');
    });

    test('a failed search counts too (the feature was used)', () async {
      final (c, _) = await launch();
      search.emit(const AiSearchState(mode: AiSearchMode.text, isLoading: true));
      search.emit(const AiSearchState(
          mode: AiSearchMode.text, errorKind: AiSearchErrorKind.unavailable));
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(c).firstSearchDone, isTrue);
    });

    test('coach mark: due once the data is there, never again once finished', () async {
      var (c, controller) = await launch();
      expect(c.read(aiCoachMarkDueProvider), isTrue);
      expect(c.read(aiHomeSettledProvider), isFalse, reason: 'waits for the coach mark');

      controller.coachMarkStarted();
      expect(c.read(aiCoachMarkDueProvider), isFalse);
      expect(c.read(aiPulseDueProvider), isFalse, reason: 'no pulse during the coach mark');

      await controller.coachMarkFinished();
      expect(c.read(aiHomeSettledProvider), isTrue);
      expect(c.read(aiPulseDueProvider), isTrue, reason: 'first session: pulse after it');

      (c, controller) = await launch();
      expect(stateOf(c).onboardingSeen, isTrue);
      expect(c.read(aiCoachMarkDueProvider), isFalse);
    });

    test('coach mark interrupted (logout): not seen, the home still settles', () async {
      final (c, controller) = await launch();
      controller.coachMarkStarted();
      controller.coachMarkInterrupted();
      expect(stateOf(c).onboardingSeen, isFalse);
      expect(c.read(aiCoachMarkDueProvider), isFalse, reason: 'not twice in a session');
      expect(c.read(aiHomeSettledProvider), isTrue);
    });

    test('no coach mark while the home data is loading', () async {
      final c = ProviderContainer(overrides: [
        aiOnboardingClockProvider.overrideWithValue(clock.call),
        aiSearchProvider.overrideWith((ref) => _FakeSearch()),
        aiHomeDataLoadedProvider.overrideWith((ref) => false),
      ]);
      addTearDown(c.dispose);
      await c.read(aiOnboardingControllerProvider.notifier).ready;
      expect(c.read(aiCoachMarkDueProvider), isFalse);
    });

    group('teaser', () {
      setUp(() {
        SharedPreferences.setMockInitialValues({AiOnboardingStore.kOnboardingSeen: true});
      });

      test('picks the time of day, and shows at most once per day', () async {
        var (c, controller) = await launch();
        expect(controller.tryShowTeaser(), isTrue);
        expect(stateOf(c).teaserMoment, AiTeaserMoment.midday);
        controller.hideTeaser();
        expect(controller.tryShowTeaser(), isFalse, reason: 'once per session');

        // New launch, same day: no.
        clock.now = DateTime(2026, 11, 6, 20, 0);
        (c, controller) = await launch();
        expect(controller.tryShowTeaser(), isFalse);

        // Next morning: yes, with the morning text.
        clock.now = DateTime(2026, 11, 7, 8, 15);
        (c, controller) = await launch();
        expect(controller.tryShowTeaser(), isTrue);
        expect(stateOf(c).teaserMoment, AiTeaserMoment.morning);
      });

      test('stops for good after the assistant was opened 3 times', () async {
        var (c, controller) = await launch();
        for (var i = 0; i < 3; i++) {
          await controller.recordChatOpened();
        }
        expect(stateOf(c).chatOpenCount, 3);
        clock.now = DateTime(2026, 11, 9, 19, 0);
        (c, controller) = await launch();
        expect(controller.tryShowTeaser(), isFalse);
      });

      test('two opens are not enough to stop it', () async {
        var (c, controller) = await launch();
        await controller.recordChatOpened();
        await controller.recordChatOpened();
        (c, controller) = await launch();
        expect(controller.tryShowTeaser(), isTrue);
        expect(stateOf(c).teaserMoment, AiTeaserMoment.midday);
      });

      test('opening the chat hides a visible teaser', () async {
        final (c, controller) = await launch();
        controller.tryShowTeaser();
        expect(stateOf(c).teaserVisible, isTrue);
        await controller.recordChatOpened();
        expect(stateOf(c).teaserVisible, isFalse);
      });

      test('never before the coach mark was seen, nor in its session', () async {
        SharedPreferences.setMockInitialValues({});
        final (_, controller) = await launch();
        expect(controller.tryShowTeaser(), isFalse, reason: 'onboarding not seen');
        controller.coachMarkStarted();
        await controller.coachMarkFinished();
        expect(controller.tryShowTeaser(), isFalse, reason: 'same session as the coach mark');
      });
    });

    test('the assistant button follows the home list scroll', () async {
      final (c, controller) = await launch();
      controller.onHomeScrolled(offset: 400, delta: 20);
      expect(stateOf(c).fabExtended, isFalse);
      controller.onHomeScrolled(offset: 200, delta: -20);
      expect(stateOf(c).fabExtended, isFalse);
      controller.onHomeScrolled(offset: 0, delta: -20);
      expect(stateOf(c).fabExtended, isTrue);
    });

    test('debug reset: every flag and counter back to a first launch', () async {
      SharedPreferences.setMockInitialValues({
        AiOnboardingStore.kOnboardingSeen: true,
        AiOnboardingStore.kFirstSearchDone: true,
        AiOnboardingStore.kChatOpenCount: 5,
        AiOnboardingStore.kSessionCount: 12,
        AiOnboardingStore.kLastTeaserDay: '2026-11-06',
        'themeMode': 'ThemeMode.dark',
      });
      final (c, controller) = await launch();
      await controller.resetAll();

      final s = stateOf(c);
      expect(s.sessionCount, 1);
      expect(s.onboardingSeen, isFalse);
      expect(s.showNewBadge, isTrue);
      expect(s.chatOpenCount, 0);
      expect(s.lastTeaserDay, isNull);
      expect(c.read(aiCoachMarkDueProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AiOnboardingStore.kOnboardingSeen), isNull);
      expect(prefs.getString('themeMode'), 'ThemeMode.dark',
          reason: 'only the AI keys are cleared');
    });
  });
}
