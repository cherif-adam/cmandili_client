import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_search/providers/ai_search_provider.dart';
import '../../restaurant/providers/restaurant_provider.dart';
import '../data/ai_onboarding_store.dart';

/// The single controller behind the two AI entry points of the home screen
/// (the ✦ Recherche IA button in the search bar, the Amana Assistant button):
/// every flag and counter of the "new feature" experience, and the rules that
/// decide what may move, show or speak.
///
/// What the user sees is decided here; the widgets only draw it and report
/// what happened (a search ran, the chat was opened, an animation ended).
/// Nothing here touches the AI search or chat logic: the first search is
/// detected by listening to [aiSearchProvider], never by changing it.

// ── Rules (pure, unit-tested) ─────────────────────────────────────────────────

/// When the teaser bubble speaks (local time of the phone).
enum AiTeaserMoment { morning, midday, evening, other }

abstract final class AiOnboardingRules {
  /// Strong animations (border shimmer, pulse halo) only in the first
  /// sessions; the subtle ones (sparkle, typewriter, collapsing button) stay.
  static const strongSessions = 5;

  /// The teaser stops for good once the assistant has been opened this often.
  static const maxChatOpensForTeaser = 3;

  /// A return to the app after this long in the background starts a session.
  static const newSessionAfter = Duration(minutes: 30);

  /// Within this many pixels of the top, the assistant button is extended.
  static const fabTopOffset = 24.0;

  /// Before 11 h morning, 11–15 h midday, from 18 h evening, else other.
  static AiTeaserMoment momentFor(DateTime t) {
    if (t.hour < 11) return AiTeaserMoment.morning;
    if (t.hour < 15) return AiTeaserMoment.midday;
    if (t.hour >= 18) return AiTeaserMoment.evening;
    return AiTeaserMoment.other;
  }

  /// `yyyy-MM-dd` of [t], for "at most once per day".
  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  static bool isNewSession({required DateTime? hiddenAt, required DateTime now}) =>
      hiddenAt != null && now.difference(hiddenAt) >= newSessionAfter;

  static bool strongAnimationsAllowed(AiOnboardingState s) =>
      s.loaded && s.sessionCount <= strongSessions;

  /// The coach mark runs once, when the home screen and its data are there.
  static bool coachMarkDue(AiOnboardingState s, {required bool homeDataLoaded}) =>
      s.loaded &&
      homeDataLoaded &&
      !s.onboardingSeen &&
      !s.coachMarkActive &&
      !s.coachMarkShownThisSession;

  /// The home screen has "settled": its data is there and no coach mark is
  /// pending or showing. Shimmer, pulse and teaser wait for this, so they
  /// never overlap the coach mark.
  static bool homeSettled(AiOnboardingState s, {required bool homeDataLoaded}) =>
      s.loaded &&
      homeDataLoaded &&
      !s.coachMarkActive &&
      (s.onboardingSeen || s.coachMarkShownThisSession);

  static bool shimmerDue(AiOnboardingState s, {required bool homeDataLoaded}) =>
      strongAnimationsAllowed(s) &&
      !s.shimmerPlayed &&
      homeSettled(s, homeDataLoaded: homeDataLoaded);

  static bool pulseDue(AiOnboardingState s, {required bool homeDataLoaded}) =>
      strongAnimationsAllowed(s) &&
      !s.pulsePlayed &&
      homeSettled(s, homeDataLoaded: homeDataLoaded);

  /// At most once a day, never once the assistant was opened
  /// [maxChatOpensForTeaser] times, never during or in the same session as
  /// the coach mark (it already introduced the assistant), once per session.
  static bool teaserAllowed(AiOnboardingState s, DateTime now) =>
      s.loaded &&
      s.onboardingSeen &&
      !s.coachMarkActive &&
      !s.coachMarkShownThisSession &&
      !s.teaserShownThisSession &&
      s.chatOpenCount < maxChatOpensForTeaser &&
      s.lastTeaserDay != dayKey(now);

  /// Material 3 pattern: extended at the top, collapsed as soon as the list
  /// scrolls down, extended again only back at the top.
  static bool fabExtendedAfterScroll({
    required bool current,
    required double offset,
    required double delta,
  }) {
    if (offset <= fabTopOffset) return true;
    if (delta > 0) return false;
    return current;
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

@immutable
class AiOnboardingState {
  const AiOnboardingState({
    this.loaded = false,
    this.sessionCount = 0,
    this.onboardingSeen = false,
    this.firstSearchDone = false,
    this.chatOpenCount = 0,
    this.lastTeaserDay,
    this.coachMarkActive = false,
    this.coachMarkShownThisSession = false,
    this.shimmerPlayed = false,
    this.pulsePlayed = false,
    this.teaserShownThisSession = false,
    this.teaserVisible = false,
    this.teaserMoment = AiTeaserMoment.other,
    this.fabExtended = true,
  });

  /// False until SharedPreferences has been read: nothing shows before.
  final bool loaded;

  // Persisted (AiOnboardingStore).
  final int sessionCount;
  final bool onboardingSeen;
  final bool firstSearchDone;
  final int chatOpenCount;
  final String? lastTeaserDay;

  // This session only.
  final bool coachMarkActive;
  final bool coachMarkShownThisSession;
  final bool shimmerPlayed;
  final bool pulsePlayed;
  final bool teaserShownThisSession;
  final bool teaserVisible;
  final AiTeaserMoment teaserMoment;
  final bool fabExtended;

  /// The "Nouveau" pill next to the ✦, until the first AI search.
  bool get showNewBadge => loaded && !firstSearchDone;

  AiOnboardingState copyWith({
    bool? loaded,
    int? sessionCount,
    bool? onboardingSeen,
    bool? firstSearchDone,
    int? chatOpenCount,
    String? lastTeaserDay,
    bool? coachMarkActive,
    bool? coachMarkShownThisSession,
    bool? shimmerPlayed,
    bool? pulsePlayed,
    bool? teaserShownThisSession,
    bool? teaserVisible,
    AiTeaserMoment? teaserMoment,
    bool? fabExtended,
  }) {
    return AiOnboardingState(
      loaded: loaded ?? this.loaded,
      sessionCount: sessionCount ?? this.sessionCount,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      firstSearchDone: firstSearchDone ?? this.firstSearchDone,
      chatOpenCount: chatOpenCount ?? this.chatOpenCount,
      lastTeaserDay: lastTeaserDay ?? this.lastTeaserDay,
      coachMarkActive: coachMarkActive ?? this.coachMarkActive,
      coachMarkShownThisSession:
          coachMarkShownThisSession ?? this.coachMarkShownThisSession,
      shimmerPlayed: shimmerPlayed ?? this.shimmerPlayed,
      pulsePlayed: pulsePlayed ?? this.pulsePlayed,
      teaserShownThisSession:
          teaserShownThisSession ?? this.teaserShownThisSession,
      teaserVisible: teaserVisible ?? this.teaserVisible,
      teaserMoment: teaserMoment ?? this.teaserMoment,
      fabExtended: fabExtended ?? this.fabExtended,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final aiOnboardingStoreProvider =
    Provider<AiOnboardingStore>((ref) => AiOnboardingStore());

/// Overridden in tests to pin the time of day.
final aiOnboardingClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Kept for the whole app run: it counts sessions and outlives the home
/// screen across logouts.
final aiOnboardingControllerProvider =
    NotifierProvider<AiOnboardingController, AiOnboardingState>(
        AiOnboardingController.new);

/// The home tab's restaurants have loaded (data or empty list), so the home
/// screen is no longer a loading state.
final aiHomeDataLoadedProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(nearbyRestaurantsProvider).hasValue);

final aiCoachMarkDueProvider = Provider.autoDispose<bool>((ref) =>
    AiOnboardingRules.coachMarkDue(ref.watch(aiOnboardingControllerProvider),
        homeDataLoaded: ref.watch(aiHomeDataLoadedProvider)));

final aiHomeSettledProvider = Provider.autoDispose<bool>((ref) =>
    AiOnboardingRules.homeSettled(ref.watch(aiOnboardingControllerProvider),
        homeDataLoaded: ref.watch(aiHomeDataLoadedProvider)));

final aiShimmerDueProvider = Provider.autoDispose<bool>((ref) =>
    AiOnboardingRules.shimmerDue(ref.watch(aiOnboardingControllerProvider),
        homeDataLoaded: ref.watch(aiHomeDataLoadedProvider)));

final aiPulseDueProvider = Provider.autoDispose<bool>((ref) =>
    AiOnboardingRules.pulseDue(ref.watch(aiOnboardingControllerProvider),
        homeDataLoaded: ref.watch(aiHomeDataLoadedProvider)));

// ── Controller ────────────────────────────────────────────────────────────────

class AiOnboardingController extends Notifier<AiOnboardingState> {
  late AiOnboardingStore _store;
  late DateTime Function() _now;
  late Future<void> _ready;
  DateTime? _hiddenAt;

  @override
  AiOnboardingState build() {
    _store = ref.watch(aiOnboardingStoreProvider);
    _now = ref.watch(aiOnboardingClockProvider);

    // The first AI search, from whatever entry point: a search that ran and
    // finished (results, no match or error alike).
    ref.listen<AiSearchState>(aiSearchProvider, (prev, next) {
      final finished = (prev?.isLoading ?? false) &&
          !next.isLoading &&
          next.mode != AiSearchMode.none;
      if (finished) markFirstSearchDone();
    });

    final lifecycle = AppLifecycleListener(
      onHide: () => onAppHidden(_now()),
      onShow: () => onAppShown(_now()),
    );
    ref.onDispose(lifecycle.dispose);

    _ready = _load();
    return const AiOnboardingState();
  }

  /// Completes once the saved flags are in [state] (tests await it).
  Future<void> get ready => _ready;

  /// A launch is a new session.
  Future<void> _load() async {
    try {
      final saved = await _store.read();
      final sessions = saved.sessionCount + 1;
      state = state.copyWith(
        loaded: true,
        sessionCount: sessions,
        onboardingSeen: saved.onboardingSeen,
        firstSearchDone: saved.firstSearchDone,
        chatOpenCount: saved.chatOpenCount,
        lastTeaserDay: saved.lastTeaserDay,
      );
      await _store.setSessionCount(sessions);
    } catch (e) {
      // Without the flags, show nothing new rather than replay everything.
      debugPrint('AiOnboardingController: $e');
    }
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  void onAppHidden(DateTime at) => _hiddenAt = at;

  /// Back after [AiOnboardingRules.newSessionAfter] in the background: a new
  /// session, so the per-session moments may play again.
  Future<void> onAppShown(DateTime at) async {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (!AiOnboardingRules.isNewSession(hiddenAt: hiddenAt, now: at)) return;
    await _ready;
    if (!state.loaded) return;
    final sessions = state.sessionCount + 1;
    state = state.copyWith(
      sessionCount: sessions,
      coachMarkShownThisSession: false,
      shimmerPlayed: false,
      pulsePlayed: false,
      teaserShownThisSession: false,
      teaserVisible: false,
      fabExtended: true,
    );
    await _store.setSessionCount(sessions);
  }

  // ── What the user did ─────────────────────────────────────────────────────

  Future<void> markFirstSearchDone() async {
    await _ready;
    if (state.firstSearchDone) return;
    state = state.copyWith(firstSearchDone: true);
    await _store.setFirstSearchDone();
  }

  /// The assistant was opened from the button or the teaser.
  Future<void> recordChatOpened() async {
    await _ready;
    final count = state.chatOpenCount + 1;
    state = state.copyWith(chatOpenCount: count, teaserVisible: false);
    await _store.setChatOpenCount(count);
  }

  // ── Home screen moments ───────────────────────────────────────────────────

  /// The home screen (re)appeared: extended button, no stale teaser.
  void homeOpened() {
    if (!state.fabExtended || state.teaserVisible) {
      state = state.copyWith(fabExtended: true, teaserVisible: false);
    }
  }

  void onHomeScrolled({required double offset, required double delta}) {
    final extended = AiOnboardingRules.fabExtendedAfterScroll(
        current: state.fabExtended, offset: offset, delta: delta);
    if (extended != state.fabExtended) {
      state = state.copyWith(fabExtended: extended);
    }
  }

  void markShimmerPlayed() {
    if (!state.shimmerPlayed) state = state.copyWith(shimmerPlayed: true);
  }

  void markPulsePlayed() {
    if (!state.pulsePlayed) state = state.copyWith(pulsePlayed: true);
  }

  /// Shows the teaser if the rules allow it right now; true when shown.
  bool tryShowTeaser() {
    final now = _now();
    if (!AiOnboardingRules.teaserAllowed(state, now)) return false;
    final day = AiOnboardingRules.dayKey(now);
    state = state.copyWith(
      teaserVisible: true,
      teaserShownThisSession: true,
      lastTeaserDay: day,
      teaserMoment: AiOnboardingRules.momentFor(now),
    );
    unawaited(_store.setLastTeaserDay(day));
    return true;
  }

  void hideTeaser() {
    if (state.teaserVisible) state = state.copyWith(teaserVisible: false);
  }

  // ── Coach mark ────────────────────────────────────────────────────────────

  void coachMarkStarted() {
    state = state.copyWith(
      coachMarkActive: true,
      coachMarkShownThisSession: true,
      teaserVisible: false,
    );
  }

  /// Finished ("Compris") or skipped ("Passer"): never shown again.
  Future<void> coachMarkFinished() async {
    await _ready;
    state = state.copyWith(coachMarkActive: false, onboardingSeen: true);
    await _store.setOnboardingSeen();
  }

  /// The home screen went away mid-way (logout): not seen, shows next session.
  void coachMarkInterrupted() {
    if (state.coachMarkActive) state = state.copyWith(coachMarkActive: false);
  }

  // ── Debug ─────────────────────────────────────────────────────────────────

  /// Replays the whole first-time experience (dev tools only).
  Future<void> resetAll() async {
    await _ready;
    await _store.clear();
    state = const AiOnboardingState(loaded: true, sessionCount: 1);
    await _store.setSessionCount(1);
  }
}
