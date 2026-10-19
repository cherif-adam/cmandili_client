import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../orders/providers/order_provider.dart';

/// The main screen's logic: which tab is shown (its state) and the room the
/// cart tab keeps free at the bottom. Auto-disposed with the screen, like
/// the State it replaces.
final homeControllerProvider =
    NotifierProvider.autoDispose<HomeController, int>(HomeController.new);

/// True while the active-order pill shows: an order awaiting the receipt
/// confirmation, or an order in progress.
final activeOrderPillShowingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(receiptPendingOrderProvider).valueOrNull != null ||
      ref.watch(activeOrderProvider).valueOrNull != null;
});

class HomeController extends AutoDisposeNotifier<int> {
  // ── State ─────────────────────────────────────────────────────────────────

  /// 0 home, 1 favourites, 2 orders, 3 cart, 4 profile.
  @override
  int build() => 0;

  // ── User actions ──────────────────────────────────────────────────────────

  void selectTab(int index) => state = index;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// The cart tab ends in its own summary and checkout button: keep them
  /// clear of the menu bar, and of the active-order pill when it shows.
  static double cartBottomInset(double screenHeight, {required bool pillShowing}) =>
      screenHeight * (0.125 + (pillShowing ? 0.075 : 0));
}
