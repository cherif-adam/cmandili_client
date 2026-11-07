import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../ai_onboarding_controller.dart';
import 'ai_coach_mark.dart';

/// Wraps the home screen for the AI entry points:
///   - registers the coach mark's showcase scope and provides
///     [AiCoachMarkScope] to the two spotlighted widgets below;
///   - starts the coach mark when [aiCoachMarkDueProvider] says so and the
///     home tab is the one showing ([onHomeTab]); a finish or a skip is
///     reported to the controller, which never shows it again;
///   - feeds the home list's vertical scroll to the controller, which
///     extends or collapses the assistant button.
///
/// No rule lives here: the controller decides, this widget only does what
/// needs a BuildContext (the showcase, the scroll notifications).
class AiOnboardingHost extends ConsumerStatefulWidget {
  const AiOnboardingHost({super.key, required this.onHomeTab, required this.child});

  final bool onHomeTab;
  final Widget child;

  @override
  ConsumerState<AiOnboardingHost> createState() => _AiOnboardingHostState();
}

class _AiOnboardingHostState extends ConsumerState<AiOnboardingHost> {
  final _searchKey = GlobalKey(debugLabel: 'ai_coach_search');
  final _chatKey = GlobalKey(debugLabel: 'ai_coach_chat');
  late final AiOnboardingController _onboarding;
  late final ShowcaseView _showcase;
  bool _startScheduled = false;

  @override
  void initState() {
    super.initState();
    // Read now: `ref` cannot be used any more in dispose().
    _onboarding = ref.read(aiOnboardingControllerProvider.notifier);
    _showcase = ShowcaseView.register(
      scope: AiCoachMarkScope.scopeName,
      onFinish: _onEnded,
      onDismiss: (_) => _onEnded(),
      // Only "Passer", "Suivant" and "Compris" move on: a stray tap on the
      // dark background must not end the tour unseen.
      disableBarrierInteraction: true,
      skipIfTargetNotPresent: true,
    );
    ref.listenManual<bool>(aiCoachMarkDueProvider, (_, due) {
      if (due) _scheduleStart();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onboarding.homeOpened();
      _scheduleStart();
    });
  }

  @override
  void didUpdateWidget(AiOnboardingHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onHomeTab && !oldWidget.onHomeTab) _scheduleStart();
  }

  @override
  void dispose() {
    // A provider cannot change while the tree is being torn down: report
    // the interrupted tour just after.
    final onboarding = _onboarding;
    scheduleMicrotask(onboarding.coachMarkInterrupted);
    _showcase.unregister();
    super.dispose();
  }

  /// After the frame, so both targets are laid out before the spotlight.
  void _scheduleStart() {
    if (_startScheduled) return;
    _startScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      _maybeStart();
    });
  }

  void _maybeStart() {
    if (!mounted || !widget.onHomeTab || _showcase.isShowcaseRunning) return;
    if (!ref.read(aiCoachMarkDueProvider)) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _showcase
      ..disableMovingAnimation = reduceMotion
      ..disableScaleAnimation = reduceMotion;
    _onboarding.coachMarkStarted();
    _showcase.startShowCase(
      [_searchKey, _chatKey],
      delay: const Duration(milliseconds: 600),
    );
  }

  void _onEnded() => unawaited(_onboarding.coachMarkFinished());

  bool _onScroll(ScrollUpdateNotification n) {
    // depth 0: the home list itself, not the horizontal rows inside it.
    if (!widget.onHomeTab || n.depth != 0 || n.metrics.axis != Axis.vertical) {
      return false;
    }
    final offset = n.metrics.pixels;
    final delta = n.scrollDelta ?? 0;
    void report() => _onboarding.onHomeScrolled(offset: offset, delta: delta);
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report());
    } else {
      report();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AiCoachMarkScope(
      searchKey: _searchKey,
      chatKey: _chatKey,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
  }
}
