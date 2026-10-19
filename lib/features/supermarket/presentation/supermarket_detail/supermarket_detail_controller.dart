import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/grocery_category.dart';
import '../../data/models/grocery_item.dart';

/// One controller per supermarket page on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces. Its state is the selected category; null means "Tout".
final supermarketDetailControllerProvider = NotifierProvider.autoDispose
    .family<SupermarketDetailController, GroceryCategory?, Object>(
        SupermarketDetailController.new);

class SupermarketDetailController
    extends AutoDisposeFamilyNotifier<GroceryCategory?, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  @override
  GroceryCategory? build(Object screenKey) => null;

  // ── User actions ──────────────────────────────────────────────────────────

  void selectCategory(GroceryCategory? category) => state = category;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// The items of the selected category, all of them for "Tout".
  List<GroceryItem> visibleItems(List<GroceryItem> items) => state == null
      ? items
      : items.where((item) => item.category == state).toList();
}
