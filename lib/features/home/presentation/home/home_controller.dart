import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_onboarding/presentation/ai_onboarding_controller.dart';
import '../../../orders/providers/order_provider.dart';

/// The main screen's logic: which tab is shown (its state), the room the
/// cart tab keeps free at the bottom, and where the floating parts sit
/// ([HomeBottomLayout]). Auto-disposed with the screen, like the State it
/// replaces.
final homeControllerProvider =
    NotifierProvider.autoDispose<HomeController, int>(HomeController.new);

/// True while the active-order pill shows: an order awaiting the receipt
/// confirmation, or an order in progress.
final activeOrderPillShowingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(receiptPendingOrderProvider).valueOrNull != null ||
      ref.watch(activeOrderProvider).valueOrNull != null;
});

/// The assistant button is extended ("Demande à Amana") at the top of the
/// home list — but stays round while the active-order pill shows: they
/// share a row, and the extended button would cover the pill.
final aiFabExtendedProvider = Provider.autoDispose<bool>((ref) {
  final extendedByScroll =
      ref.watch(aiOnboardingControllerProvider.select((s) => s.fabExtended));
  return extendedByScroll && !ref.watch(activeOrderPillShowingProvider);
});

class HomeController extends AutoDisposeNotifier<int> {
  // ── State ─────────────────────────────────────────────────────────────────

  /// 0 home, 1 favourites, 2 orders, 3 cart, 4 profile.
  @override
  int build() => 0;

  // ── User actions ──────────────────────────────────────────────────────────

  void selectTab(int index) => state = index;
}

/// Where the floating parts of the home screen sit, from the bottom edge of
/// the screen. The app draws edge-to-edge, so the system navigation bar
/// (3 buttons, or the gesture handle) is underneath: everything starts from
/// [systemBottom] = `MediaQuery.viewPaddingOf(context).bottom`.
///
///   ┌ list end ............................ contentBottom
///   │ active-order pill  │ assistant button  (same row)
///   ├ ................................. pillBottom
///   │ floating menu bar
///   ├ ................................. navBottom = systemBottom + 10
///   └ system navigation bar
@immutable
class HomeBottomLayout {
  const HomeBottomLayout({
    required this.systemBottom,
    required this.navHeight,
    required this.pillShowing,
  });

  /// System bar → menu bar.
  static const double navGap = 10;

  /// Menu bar → pill / assistant button, and pill → end of a list.
  static const double stackGap = 12;

  /// Height of the active-order pill (two lines of text and paddings).
  static const double pillHeight = 56;

  final double systemBottom;
  final double navHeight;
  final bool pillShowing;

  double get navBottom => systemBottom + navGap;
  double get navTop => navBottom + navHeight;
  double get pillBottom => navTop + stackGap;

  /// How far above the Scaffold's own button position (system bar + 16)
  /// the assistant button goes, to sit on the pill's row.
  double get fabLift =>
      math.max(0, pillBottom - (systemBottom + kFloatingActionButtonMargin));

  /// Room a scrolling tab keeps free after its last item, system bar
  /// included.
  double get contentBottom =>
      navTop + stackGap + (pillShowing ? pillHeight + stackGap : 0);

  /// The same, without the system bar: for a panel that already sits in a
  /// SafeArea (the cart summary).
  double get floatingRoom => contentBottom - systemBottom;

  @override
  bool operator ==(Object other) =>
      other is HomeBottomLayout &&
      other.systemBottom == systemBottom &&
      other.navHeight == navHeight &&
      other.pillShowing == pillShowing;

  @override
  int get hashCode => Object.hash(systemBottom, navHeight, pillShowing);
}
