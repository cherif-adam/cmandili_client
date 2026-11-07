import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../ai_onboarding/presentation/ai_entry_navigation.dart';
import '../../../../ai_onboarding/presentation/ai_onboarding_controller.dart';
import '../../../../ai_onboarding/presentation/widgets/ai_coach_mark.dart';
import '../../../../ai_onboarding/presentation/widgets/ai_new_badge.dart';
import '../../../../ai_onboarding/presentation/widgets/ai_shimmer_border.dart';
import '../../../../ai_onboarding/presentation/widgets/twinkling_sparkle.dart';
import '../../../../ai_onboarding/presentation/widgets/typewriter_hint.dart';

/// The white search box under the home header.
///
///   - Typing filters the restaurant list, as before; the keyboard's
///     "Rechercher" key sends the text to Recherche IA instead.
///   - Placeholder: AI example prompts typed one by one while the field is
///     empty and not focused (fixed text with reduced motion); the plain
///     "Rechercher des restaurants..." once focused.
///   - Right side: the "Nouveau" pill until the first AI search, and the
///     twinkling ✦ that opens Recherche IA (a ✕ that clears the text once
///     something is typed).
///   - Border: a one-time shimmer in the AI gradient, early sessions only.
///   - Coach mark step 1 spotlights this box.
///
/// What shows when is decided by AiOnboardingController.
class HomeSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final double screenWidth;
  final double screenHeight;

  const HomeSearchField({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  ConsumerState<HomeSearchField> createState() => _HomeSearchFieldState();
}

class _HomeSearchFieldState extends ConsumerState<HomeSearchField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    AiEntryNavigation.openSearch(context, query: text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final showBadge =
        ref.watch(aiOnboardingControllerProvider.select((s) => s.showNewBadge));
    final shimmer = !reduceMotion && ref.watch(aiShimmerDueProvider);

    final width = widget.screenWidth;
    final height = widget.screenHeight;
    final radius = width * 0.04;
    final fontSize = width * 0.038;
    final hintStyle = TextStyle(
      color: AppColors.textSecondary.withValues(alpha: 0.5),
      fontSize: fontSize,
    );

    return Container(
      height: height * 0.1,
      padding: EdgeInsets.symmetric(horizontal: width * 0.05, vertical: height * 0.012),
      alignment: Alignment.topCenter,
      child: AiCoachMarkTarget(
        step: AiCoachStep.search,
        borderRadius: BorderRadius.circular(radius),
        child: AiShimmerBorder(
          play: shimmer,
          borderRadius: radius,
          onPlayed: ref.read(aiOnboardingControllerProvider.notifier).markShimmerPlayed,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: width * 0.025,
                  offset: Offset(0, height * 0.006),
                ),
              ],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: fontSize,
              ),
              decoration: InputDecoration(
                hint: _hint(l10n, hintStyle, reduceMotion),
                prefixIcon: Icon(Icons.search, color: AppColors.primary, size: width * 0.06),
                suffixIcon: widget.query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: width * 0.05),
                        onPressed: widget.onCleared,
                      )
                    : _AiSuffix(
                        showBadge: showBadge,
                        animate: !reduceMotion,
                        tooltip: l10n.aiSearchTitle,
                        onPressed: () => AiEntryNavigation.openSearch(context),
                      ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: width * 0.05,
                  vertical: height * 0.017,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _hint(AppLocalizations l10n, TextStyle style, bool reduceMotion) {
    // Text typed: no hint at all (and no typewriter ticking behind it).
    if (widget.query.isNotEmpty) return null;
    Widget fixed(String text) =>
        Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (_focused) return fixed(l10n.searchRestaurants);
    if (reduceMotion) return fixed(l10n.aiSearchFieldStaticHint);
    return TypewriterHint(
      phrases: [l10n.aiTypewriter1, l10n.aiTypewriter2, l10n.aiTypewriter3, l10n.aiTypewriter4],
      style: style,
    );
  }
}

/// "Nouveau" pill (until the first AI search) + the twinkling ✦ button.
class _AiSuffix extends StatelessWidget {
  const _AiSuffix({
    required this.showBadge,
    required this.animate,
    required this.tooltip,
    required this.onPressed,
  });

  final bool showBadge;
  final bool animate;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBadge) const AiNewBadge(),
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: TwinklingSparkle(size: 24, animate: animate),
        ),
      ],
    );
  }
}
