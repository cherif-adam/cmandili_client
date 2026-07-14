import 'item_variant.dart';

/// One selectable choice inside a [FoodItemOptionGroup], e.g. "Harissa" (0 TND)
/// or "Gruyère" (6 TND). `price` is a raw add-on charged on top of the food
/// item's base price — never marked up here; markup is applied once, at
/// `CartItem.price`.
class FoodItemOption {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;
  final int sortOrder;

  const FoodItemOption({
    required this.id,
    required this.name,
    required this.price,
    this.isAvailable = true,
    this.sortOrder = 0,
  });

  factory FoodItemOption.fromDb(Map<String, dynamic> row) {
    return FoodItemOption(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      price: (row['price'] as num?)?.toDouble() ?? 0.0,
      isAvailable: row['is_available'] as bool? ?? true,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A reusable, restaurant-owned customization group (e.g. "Sauce au choix"),
/// linked to one or more food items via `food_item_option_group_links`.
///
/// `sortOrder` here is the *link's* position for the item this group was
/// fetched for, not the group's own restaurant-level default — the same
/// group can be ordered differently across the different items it's linked
/// to. `options` only contains available options (unavailable ones are
/// filtered out at parse time, same as `getFoodItemVariants` does).
class FoodItemOptionGroup {
  final String id;
  final String name;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;
  final int sortOrder;
  final List<FoodItemOption> options;

  const FoodItemOptionGroup({
    required this.id,
    required this.name,
    required this.minSelections,
    required this.maxSelections,
    required this.isRequired,
    required this.sortOrder,
    required this.options,
  });

  /// `linkRow` is one row from the `food_item_option_group_links` select,
  /// with the nested `food_item_option_groups(...food_item_options(...))`
  /// resource embedded by PostgREST.
  factory FoodItemOptionGroup.fromDb(Map<String, dynamic> linkRow) {
    final group = linkRow['food_item_option_groups'] as Map<String, dynamic>? ?? const {};
    final rawOptions = (group['food_item_options'] as List?) ?? const [];
    final options = rawOptions
        .map((o) => FoodItemOption.fromDb(o as Map<String, dynamic>))
        .where((o) => o.isAvailable)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return FoodItemOptionGroup(
      id: group['id'] as String? ?? '',
      name: group['name'] as String? ?? '',
      minSelections: (group['min_selections'] as num?)?.toInt() ?? 0,
      maxSelections: (group['max_selections'] as num?)?.toInt() ?? 1,
      isRequired: group['is_required'] as bool? ?? false,
      sortOrder: (linkRow['sort_order'] as num?)?.toInt() ?? 0,
      options: options,
    );
  }
}

/// Everything the customization sheet needs for one food item, fetched
/// together so the sheet has a single loading/error state instead of two.
class FoodItemCustomizationOptions {
  final List<ItemVariant> variants;
  final List<FoodItemOptionGroup> optionGroups;

  const FoodItemCustomizationOptions({
    required this.variants,
    required this.optionGroups,
  });

  bool get hasCustomization => variants.isNotEmpty || optionGroups.isNotEmpty;
}
