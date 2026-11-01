import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Brings one dish of a shop's page into view and makes it glow for a
/// moment, so a customer arriving from a search result sees which dish it
/// was.
///
/// Menus are lazy lists: a dish far down is not built until the list gets
/// near it, so it cannot be scrolled to directly. [reveal] moves down most of
/// a screen at a time until the dish is built, then brings it to a third of
/// the screen (below the pinned category chips) and lights it.
class DishSpotlight {
  DishSpotlight(this.itemId);

  /// The dish to show; null when the page was opened normally.
  final String? itemId;

  /// True while the dish glows.
  final ValueNotifier<bool> lit = ValueNotifier(false);

  static const glow = Duration(milliseconds: 1600);

  final GlobalKey _key = GlobalKey();
  bool _started = false;
  bool _disposed = false;

  /// [child] inside the glow when it is the dish, unchanged otherwise.
  /// [radius] is the card's corners and [margin] its own outer margin, so the
  /// glow hugs the card and not the gap after it.
  Widget frame(
    String id,
    Widget child, {
    double radius = 16,
    EdgeInsets margin = EdgeInsets.zero,
  }) =>
      id == itemId
          ? SpotlightFrame(key: _key, lit: lit, radius: radius, margin: margin, child: child)
          : child;

  /// Call once the list is on screen; only the first call does anything.
  /// The pages call it only when the dish is in their list; should it not be
  /// found anyway, the list goes back to where it was.
  Future<void> reveal(ScrollController scroll) async {
    if (itemId == null || _started) return;
    _started = true;
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || !scroll.hasClients) return;
    final start = scroll.position.pixels;
    for (var step = 0; step < 60 && _key.currentContext == null; step++) {
      if (_disposed || !scroll.hasClients) return;
      final position = scroll.position;
      if (position.pixels >= position.maxScrollExtent) break;
      scroll.jumpTo(math.min(
        position.pixels + position.viewportDimension * 0.8,
        position.maxScrollExtent,
      ));
      await WidgetsBinding.instance.endOfFrame;
    }
    final context = _key.currentContext;
    if (_disposed) return;
    if (context == null) {
      if (scroll.hasClients) scroll.jumpTo(start);
      return;
    }
    if (!context.mounted) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.3,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    if (_disposed) return;
    lit.value = true;
    await Future<void>.delayed(glow);
    if (!_disposed) lit.value = false;
  }

  void dispose() {
    _disposed = true;
    lit.dispose();
  }
}

/// The glow around the spotlit dish: an outline and a light tint over the
/// card that fade in and out. Painted over [child] without moving it, and
/// taps go through to the card.
class SpotlightFrame extends StatelessWidget {
  const SpotlightFrame({
    super.key,
    required this.lit,
    required this.child,
    this.radius = 16,
    this.margin = EdgeInsets.zero,
  });

  final ValueListenable<bool> lit;
  final Widget child;
  final double radius;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: margin.left,
          top: margin.top,
          right: margin.right,
          bottom: margin.bottom,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: lit,
              builder: (context, on, _) => AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
