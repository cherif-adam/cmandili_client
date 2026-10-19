import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/food_item.dart';

/// One controller per restaurant page on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces. Its state is the selected menu category.
final restaurantDetailControllerProvider = NotifierProvider.autoDispose
    .family<RestaurantDetailController, String, Object>(
        RestaurantDetailController.new);

class RestaurantDetailController extends AutoDisposeFamilyNotifier<String, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  /// The "Tout" chip. MenuCategoryChips shows this value as "Tout".
  static const all = 'All';

  @override
  String build(Object screenKey) => all;

  // ── User actions ──────────────────────────────────────────────────────────

  void selectCategory(String category) => state = category;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// 'All' first, then the menu's own sections in the order they appear.
  List<String> categoriesOf(List<FoodItem> menuItems) =>
      [all, ...menuItems.map((e) => e.category).toSet()];

  /// The dishes of the selected category, every dish for 'All'.
  List<FoodItem> visibleItems(List<FoodItem> menuItems) => state == all
      ? menuItems
      : menuItems.where((item) => item.category == state).toList();
}
