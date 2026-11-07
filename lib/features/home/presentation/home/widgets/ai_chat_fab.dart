import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../ai_onboarding/presentation/ai_entry_navigation.dart';
import '../../../../ai_onboarding/presentation/ai_onboarding_controller.dart';
import '../../../../ai_onboarding/presentation/widgets/ai_assistant_button.dart';
import '../../../../ai_onboarding/presentation/widgets/ai_coach_mark.dart';
import '../../../../ai_onboarding/presentation/widgets/ai_pulse_halo.dart';
import '../../../../ai_onboarding/presentation/widgets/ai_teaser_bubble.dart';
import '../home_controller.dart';

/// The Amana Assistant entry point (home tab only), bottom to top:
///
///   AiAssistantButton  "Demande à Amana", collapsing to the round icon
///                      when the list scrolls down (AiPulseHalo around it in
///                      the first sessions; coach mark step 2 spotlights it)
///   AiTeaserBubble     about 5 s after the home screen settles, at most
///                      once a day, never after 3 chat opens
///
/// What shows when is decided by AiOnboardingController; this widget only
/// measures the 5 s, on a ticker, so time under another screen or in the
/// background does not count.
///
/// [bottomLift] raises it from the Scaffold's own button position onto the
/// active-order pill's row, above the floating menu bar
/// (HomeBottomLayout.fabLift). It stays round while that pill shows
/// (aiFabExtendedProvider).
class AiChatFab extends ConsumerStatefulWidget {
  const AiChatFab({super.key, this.bottomLift = 0});

  static const teaserDelay = Duration(seconds: 5);

  final double bottomLift;

  @override
  ConsumerState<AiChatFab> createState() => _AiChatFabState();
}

class _AiChatFabState extends ConsumerState<AiChatFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _teaserDelay =
      AnimationController(vsync: this, duration: AiChatFab.teaserDelay)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            ref.read(aiOnboardingControllerProvider.notifier).tryShowTeaser();
          }
        });

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(aiHomeSettledProvider, (_, settled) {
      if (settled) {
        _teaserDelay.forward(from: 0);
      } else {
        _teaserDelay.stop();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _teaserDelay.dispose();
    super.dispose();
  }

  void _openChat() => AiEntryNavigation.openChat(context, ref);

  static String _teaserText(AppLocalizations l10n, AiTeaserMoment moment) =>
      switch (moment) {
        AiTeaserMoment.morning => l10n.aiTeaserMorning,
        AiTeaserMoment.midday => l10n.aiTeaserMidday,
        AiTeaserMoment.evening => l10n.aiTeaserEvening,
        AiTeaserMoment.other => l10n.aiTeaserDefault,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final onboarding = ref.read(aiOnboardingControllerProvider.notifier);
    final extended = ref.watch(aiFabExtendedProvider);
    final teaser = ref.watch(aiOnboardingControllerProvider
        .select((s) => s.teaserVisible ? s.teaserMoment : null));
    final pulse = !reduceMotion && ref.watch(aiPulseDueProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomLift),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (teaser != null) ...[
            AiTeaserBubble(
              text: _teaserText(l10n, teaser),
              reduceMotion: reduceMotion,
              onTap: _openChat,
              onClose: onboarding.hideTeaser,
              onTimeout: onboarding.hideTeaser,
            ),
            const SizedBox(height: 6),
          ],
          AiCoachMarkTarget(
            step: AiCoachStep.chat,
            borderRadius: BorderRadius.circular(AiAssistantButton.height / 2),
            child: AiPulseHalo(
              play: pulse,
              onDone: onboarding.markPulsePlayed,
              child: AiAssistantButton(
                extended: extended,
                label: l10n.aiAskAmana,
                tooltip: l10n.aiChatTooltip,
                reduceMotion: reduceMotion,
                onPressed: _openChat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
