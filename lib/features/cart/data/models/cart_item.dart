import '../../../menu/data/models/item_variant.dart';
import '../../../restaurant/data/models/food_item.dart';
import '../../../supermarket/data/models/grocery_item.dart';
import '../../../../core/utils/platform_pricing.dart';
import 'order_customization.dart';

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

  CartItem.restaurant({
    required this.foodItem,
    this.quantity = 1,
    this.specialInstructions,
    this.customization,
    this.variant,
  })  : type = CartItemType.restaurant,
        groceryItem = null;

  CartItem.grocery({
    required this.groceryItem,
    this.quantity = 1,
    this.variant,
  })  : type = CartItemType.grocery,
        foodItem = null,
        specialInstructions = null,
        customization = null;

  String get id => type == CartItemType.restaurant ? foodItem!.id : groceryItem!.id;
  String get name {
    final base = type == CartItemType.restaurant ? foodItem!.name : groceryItem!.name;
    return variant != null ? '$base — ${variant!.name}' : base;
  }
  double get price {
    // All prices are base + 10% platform fee via clientPrice / applyPlatformMarkup.
    // This getter is the single source used for cart totals, checkout, and the
    // order_items.price column stored in the DB — so the markup is always applied.
    if (variant != null) return applyPlatformMarkup(variant!.price);
    if (type == CartItemType.restaurant) return foodItem!.clientPrice;
    return groceryItem!.clientPrice;
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

    if (type == CartItemType.grocery) {
      return CartItem.grocery(
        groceryItem: GroceryItem.fromJson(json['groceryItem']),
        quantity: json['quantity'] ?? 1,
        variant: variant,
      );
    } else {
      return CartItem.restaurant(
        foodItem: FoodItem.fromJson(json['foodItem']),
        quantity: json['quantity'] ?? 1,
        specialInstructions: json['specialInstructions'],
        variant: variant,
      );
    }
  }
}
