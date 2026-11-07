import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/theme/app_colors.dart';

/// The two steps of the one-time AI coach mark.
enum AiCoachStep { search, chat }

/// Put above the home screen by AiOnboardingHost once it has registered the
/// showcase scope; carries the keys of the two spotlighted widgets.
///
/// A `Showcase` throws if no showcase is registered for its scope, so the
/// targets only wrap themselves when this scope is above them
/// ([AiCoachMarkTarget]): the search field and the assistant button keep
/// working anywhere else, tests included.
class AiCoachMarkScope extends InheritedWidget {
  const AiCoachMarkScope({
    super.key,
    required this.searchKey,
    required this.chatKey,
    required super.child,
  });

  static const scopeName = 'ai_onboarding';

  final GlobalKey searchKey;
  final GlobalKey chatKey;

  static AiCoachMarkScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiCoachMarkScope>();

  @override
  bool updateShouldNotify(AiCoachMarkScope oldWidget) =>
      oldWidget.searchKey != searchKey || oldWidget.chatKey != chatKey;
}

/// Spotlights [child] for its [step] of the coach mark: title, text, and
/// "Passer" plus "Suivant" (search) or "Compris" (assistant).
class AiCoachMarkTarget extends StatelessWidget {
  const AiCoachMarkTarget({
    super.key,
    required this.step,
    required this.child,
    this.borderRadius,
  });

  final AiCoachStep step;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scope = AiCoachMarkScope.maybeOf(context);
    if (scope == null) return child;

    final l10n = AppLocalizations.of(context)!;
    final isSearch = step == AiCoachStep.search;
    return Showcase(
      key: isSearch ? scope.searchKey : scope.chatKey,
      scope: AiCoachMarkScope.scopeName,
      title: isSearch ? l10n.aiCoachSearchTitle : l10n.aiCoachChatTitle,
      description: isSearch ? l10n.aiCoachSearchBody : l10n.aiCoachChatBody,
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.aiViolet,
      ),
      descTextStyle: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: AppColors.textPrimary,
      ),
      tooltipBackgroundColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(16),
      tooltipPadding: const EdgeInsets.all(14),
      targetBorderRadius: borderRadius,
      targetPadding: const EdgeInsets.all(4),
      overlayOpacity: 0.7,
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.spaceBetween,
        position: TooltipActionPosition.inside,
        gapBetweenContentAndAction: 12,
      ),
      tooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: l10n.aiCoachSkip,
          backgroundColor: Colors.transparent,
          textStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: isSearch ? l10n.aiCoachNext : l10n.aiCoachDone,
          backgroundColor: AppColors.aiViolet,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      child: child,
    );
  }
}
