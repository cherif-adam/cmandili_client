import '../../../menu/data/models/item_variant.dart';
import '../../../restaurant/data/models/food_item.dart';
import '../../../supermarket/data/models/grocery_item.dart';
import '../../../../core/utils/platform_pricing.dart';
import 'order_customization.dart';
import 'selected_option_group.dart';

enum CartItemType {
  restaurant,
  grocery,
}

class CartItem {
  final CartItemType type;
  final FoodItem? foodItem;
  final GroceryItem? groceryItem;
  int quantity;
  final String? specialInstructions;
  OrderCustomization? customization;
  final ItemVariant? variant;
  final List<SelectedOptionGroup> selectedOptionGroups;

  CartItem.restaurant({
    required this.foodItem,
    this.quantity = 1,
    this.specialInstructions,
    this.customization,
    this.variant,
    this.selectedOptionGroups = const [],
  })  : type = CartItemType.restaurant,
        groceryItem = null;

  CartItem.grocery({
    required this.groceryItem,
    this.quantity = 1,
    this.variant,
    this.selectedOptionGroups = const [],
  })  : type = CartItemType.grocery,
        foodItem = null,
        specialInstructions = null,
        customization = null;

  String get id => type == CartItemType.restaurant ? foodItem!.id : groceryItem!.id;

  /// Composite cart-line identity. The base [id] alone isn't enough once an
  /// item can be added with a variant and/or option-group selections — two
  /// lines for the same item with different picks must stay separate, while
  /// two lines with the *same* final picks (chosen in any tap order) must
  /// merge. Selections are sorted before joining so tap order never matters.
  String get cartLineKey => '${type.name}:$id:${variant?.id ?? '-'}:$_optionsSignature';

  String get _optionsSignature {
    if (selectedOptionGroups.isEmpty) return '';
    final parts = selectedOptionGroups.map((g) {
      final ids = g.selections.map((s) => s.optionId).toList()..sort();
      return '${g.groupId}=${ids.join(',')}';
    }).toList()
      ..sort();
    return parts.join('|');
  }

  String get name {
    final base = type == CartItemType.restaurant ? foodItem!.name : groceryItem!.name;
    return variant != null ? '$base — ${variant!.name}' : base;
  }

  /// One-line summary of selected add-ons for the cart screen, e.g.
  /// "Harissa, Gruyère". Null when nothing was selected.
  String? get optionsSummary => selectedOptionGroups.isEmpty
      ? null
      : selectedOptionGroups.expand((g) => g.selections).map((s) => s.name).join(', ');

  double get price {
    // Raw base (or variant-replacement) price + raw selected add-ons, with
    // the 10% platform fee applied ONCE to the sum — never per-component.
    // This getter is the single source used for cart totals, checkout, and
    // the order_items.price column stored in the DB.
    final unitBase = variant != null
        ? variant!.price
        : (type == CartItemType.restaurant
            ? (foodItem!.discountPrice ?? foodItem!.price)
            : (groceryItem!.discountPrice ?? groceryItem!.price));
    final addOns = selectedOptionGroups
        .expand((g) => g.selections)
        .fold(0.0, (sum, s) => sum + s.price);
    return applyPlatformMarkup(unitBase + addOns);
  }

  String get imageUrl => type == CartItemType.restaurant ? foodItem!.imageUrl : groceryItem!.imageUrl;

  double get totalPrice => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'quantity': quantity,
      'specialInstructions': specialInstructions,
      if (type == CartItemType.restaurant) 'foodItem': foodItem?.toJson(),
      if (type == CartItemType.grocery) 'groceryItem': groceryItem?.toJson(),
      if (variant != null) 'variant': variant!.toJson(),
      if (selectedOptionGroups.isNotEmpty)
        'selectedOptionGroups': selectedOptionGroups.map((g) => g.toJson()).toList(),
      // Customization skipped for simplicity as before
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = typeStr == 'grocery' ? CartItemType.grocery : CartItemType.restaurant;
    final variantJson = json['variant'];
    final variant = variantJson is Map<String, dynamic>
        ? ItemVariant.fromJson(variantJson)
        : null;
    final selectedOptionGroups = ((json['selectedOptionGroups'] as List?) ?? const [])
        .map((g) => SelectedOptionGroup.fromJson(g as Map<String, dynamic>))
        .toList();

    if (type == CartItemType.grocery) {
      return CartItem.grocery(
        groceryItem: GroceryItem.fromJson(json['groceryItem']),
        quantity: json['quantity'] ?? 1,
        variant: variant,
        selectedOptionGroups: selectedOptionGroups,
      );
    } else {
      return CartItem.restaurant(
        foodItem: FoodItem.fromJson(json['foodItem']),
        quantity: json['quantity'] ?? 1,
        specialInstructions: json['specialInstructions'],
        variant: variant,
        selectedOptionGroups: selectedOptionGroups,
      );
    }
  }
}
