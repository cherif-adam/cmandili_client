import 'package:shared_preferences/shared_preferences.dart';

/// What the AI onboarding remembers between launches.
class AiOnboardingSnapshot {
  const AiOnboardingSnapshot({
    this.sessionCount = 0,
    this.onboardingSeen = false,
    this.firstSearchDone = false,
    this.chatOpenCount = 0,
    this.lastTeaserDay,
  });

  /// Sessions started so far (see AiOnboardingRules.newSessionAfter).
  final int sessionCount;

  /// The two-step coach mark was finished or skipped.
  final bool onboardingSeen;

  /// The customer ran at least one Recherche IA search.
  final bool firstSearchDone;

  /// Times the assistant was opened from its home entry points.
  final int chatOpenCount;

  /// Day the teaser bubble last showed, as `yyyy-MM-dd` (local time).
  final String? lastTeaserDay;
}

/// SharedPreferences for the AI entry points. One key per flag or counter;
/// [clear] removes exactly these keys and nothing else of the app.
class AiOnboardingStore {
  static const kOnboardingSeen = 'ai_onboarding_seen';
  static const kSessionCount = 'ai_session_count';
  static const kFirstSearchDone = 'ai_first_search_done';
  static const kChatOpenCount = 'ai_chat_open_count';
  static const kLastTeaserDay = 'ai_last_teaser_day';

  static const allKeys = [
    kOnboardingSeen,
    kSessionCount,
    kFirstSearchDone,
    kChatOpenCount,
    kLastTeaserDay,
  ];

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<AiOnboardingSnapshot> read() async {
    final p = await _prefs;
    return AiOnboardingSnapshot(
      sessionCount: p.getInt(kSessionCount) ?? 0,
      onboardingSeen: p.getBool(kOnboardingSeen) ?? false,
      firstSearchDone: p.getBool(kFirstSearchDone) ?? false,
      chatOpenCount: p.getInt(kChatOpenCount) ?? 0,
      lastTeaserDay: p.getString(kLastTeaserDay),
    );
  }

  Future<void> setSessionCount(int value) async =>
      (await _prefs).setInt(kSessionCount, value);

  Future<void> setOnboardingSeen() async =>
      (await _prefs).setBool(kOnboardingSeen, true);

  Future<void> setFirstSearchDone() async =>
      (await _prefs).setBool(kFirstSearchDone, true);

  Future<void> setChatOpenCount(int value) async =>
      (await _prefs).setInt(kChatOpenCount, value);

  Future<void> setLastTeaserDay(String day) async =>
      (await _prefs).setString(kLastTeaserDay, day);

  Future<void> clear() async {
    final p = await _prefs;
    for (final key in allKeys) {
      await p.remove(key);
    }
  }
}
