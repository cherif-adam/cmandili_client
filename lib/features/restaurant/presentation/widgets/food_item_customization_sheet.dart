import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/models/cart_item.dart';
import '../../../cart/data/models/order_customization.dart';
import '../../../cart/data/models/selected_option_group.dart';
import '../../../cart/presentation/add_to_cart_guard.dart';
import '../../../menu/data/models/item_variant.dart';
import '../../../menu/data/models/food_item_option_group.dart';
import '../../data/models/food_item.dart';
import '../../providers/restaurant_provider.dart';
import '../../../../core/widgets/sheet_drag_handle.dart';
import 'add_to_cart_bar.dart';
import 'customization_group.dart';
import 'food_sheet_header.dart';
import 'option_group_section.dart';
import 'quantity_selector.dart';
import 'special_instructions_field.dart';

/// Bottom sheet shown when a customer taps a food item: image/name/price,
/// then any variants ("Type au choix") and option groups ("Sauce au choix",
/// "Suppléments", ...), special instructions, quantity, and Add to Cart.
/// Items with neither variants nor option groups render the same sheet with
/// no group sections — the group list is simply empty, so this looks and
/// behaves exactly like the pre-customization dialog.
///
/// Top to bottom: SheetDragHandle, FoodSheetHeader, one
/// OptionGroupSection per group, SpecialInstructionsField,
/// QuantitySelector — then the AddToCartBar pinned at the bottom.
class FoodItemCustomizationSheet extends ConsumerStatefulWidget {
  final FoodItem item;
  final bool isOpen;

  const FoodItemCustomizationSheet({
    super.key,
    required this.item,
    required this.isOpen,
  });

  @override
  ConsumerState<FoodItemCustomizationSheet> createState() =>
      _FoodItemCustomizationSheetState();
}

const _variantGroupKey = 'variant';

class _FoodItemCustomizationSheetState
    extends ConsumerState<FoodItemCustomizationSheet> {
  int _quantity = 1;
  final Map<String, Set<String>> _selections = {};
  List<CustomizationGroup> _displayGroups = const [];
  List<GlobalKey> _groupKeys = const [];
  bool _initialized = false;

  final _instructionsController = TextEditingController();
  final _scrollController = ScrollController();
  int? _highlightedGroupIndex;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _instructionsController.dispose();
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _initFromData(FoodItemCustomizationOptions data, AppLocalizations l10n) {
    if (_initialized) return;
    _initialized = true;
    final groups = <CustomizationGroup>[];
    if (data.variants.isNotEmpty) {
      groups.add(CustomizationGroup(
        key: _variantGroupKey,
        title: l10n.variantGroupTitle,
        minSelections: 1,
        maxSelections: 1,
        isRequired: true,
        options: data.variants
            .map((v) => CustomizationOption(id: v.id, name: v.name, price: v.price))
            .toList(),
      ));
    }
    for (final g in data.optionGroups) {
      if (g.options.isEmpty) continue; // no purchasable option -> don't block the item
      groups.add(CustomizationGroup(
        key: g.id,
        title: g.name,
        minSelections: g.minSelections,
        maxSelections: g.maxSelections,
        isRequired: g.isRequired,
        options: g.options
            .map((o) => CustomizationOption(id: o.id, name: o.name, price: o.price))
            .toList(),
      ));
    }
    _displayGroups = groups;
    _groupKeys = List.generate(groups.length, (_) => GlobalKey());
  }

  void _toggleOption(CustomizationGroup group, CustomizationOption option) {
    setState(() {
      final current = _selections.putIfAbsent(group.key, () => <String>{});
      if (group.maxSelections == 1) {
        current
          ..clear()
          ..add(option.id);
      } else if (current.contains(option.id)) {
        current.remove(option.id);
      } else if (current.length < group.maxSelections) {
        current.add(option.id);
      }
      // else: group already at its cap — tapping a new option is a no-op.
    });
  }

  bool _isGroupSatisfied(CustomizationGroup group) {
    final count = _selections[group.key]?.length ?? 0;
    return count >= group.minSelections && count <= group.maxSelections;
  }

  int? _firstInvalidIndex() {
    for (var i = 0; i < _displayGroups.length; i++) {
      if (!_isGroupSatisfied(_displayGroups[i])) return i;
    }
    return null;
  }

  CartItem _buildCartItem() {
    ItemVariant? variant;
    final selectedOptionGroups = <SelectedOptionGroup>[];

    for (final group in _displayGroups) {
      final selectedIds = _selections[group.key] ?? const <String>{};
      if (selectedIds.isEmpty) continue;
      final selectedOptions =
          group.options.where((o) => selectedIds.contains(o.id)).toList();
      if (selectedOptions.isEmpty) continue;

      if (group.key == _variantGroupKey) {
        final v = selectedOptions.first;
        variant = ItemVariant(id: v.id, name: v.name, price: v.price);
      } else {
        selectedOptionGroups.add(SelectedOptionGroup(
          groupId: group.key,
          groupName: group.title,
          selections: selectedOptions
              .map((o) => SelectedOption(optionId: o.id, name: o.name, price: o.price))
              .toList(),
        ));
      }
    }

    final text = _instructionsController.text.trim();
    final customization = text.isEmpty
        ? null
        : OrderCustomization(
            type: CustomizationType.text,
            content: text,
            timestamp: DateTime.now(),
          );

    return CartItem.restaurant(
      foodItem: widget.item,
      quantity: _quantity,
      variant: variant,
      selectedOptionGroups: selectedOptionGroups,
      customization: customization,
    );
  }

  void _scrollToAndHighlight(int index, AppLocalizations l10n) {
    final keyContext = _groupKeys[index].currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
    setState(() => _highlightedGroupIndex = index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.completeRequiredSelections),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlightedGroupIndex = null);
    });
  }

  Future<void> _handleAddToCartTap(AppLocalizations l10n) async {
    final invalidIndex = _firstInvalidIndex();
    if (invalidIndex != null) {
      _scrollToAndHighlight(invalidIndex, l10n);
      return;
    }
    final cartItem = _buildCartItem();
    // Un panier appartient à UNE boutique : le checkout lit la boutique dans
    // cartItems.first et lui attribue la commande entière. Sans ce garde-fou,
    // un plat ajouté par-dessus un panier d'une autre boutique serait facturé
    // au mauvais commerçant.
    final added = await addToCartGuarded(context, ref, cartItem);
    if (!added || !mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            l10n.addedToCartWithQuantity(_quantity, widget.item.name)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final optionsAsync =
        ref.watch(foodItemCustomizationOptionsProvider(widget.item.id));
    final data = optionsAsync.maybeWhen(
      data: (d) => d,
      orElse: () => const FoodItemCustomizationOptions(variants: [], optionGroups: []),
    );
    if (optionsAsync.hasValue) {
      _initFromData(data, l10n);
    }
    final isLoadingOptions = optionsAsync.isLoading;
    final restaurantClosed = !widget.isOpen;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SheetDragHandle(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FoodSheetHeader(item: widget.item),
                  const SizedBox(height: 24),

                  // Variants + option groups (none for a plain item)
                  for (var i = 0; i < _displayGroups.length; i++)
                    OptionGroupSection(
                      key: _groupKeys[i],
                      group: _displayGroups[i],
                      selectedIds: _selections[_displayGroups[i].key] ?? const <String>{},
                      highlighted: _highlightedGroupIndex == i,
                      onToggle: (option) => _toggleOption(_displayGroups[i], option),
                    ),

                  SpecialInstructionsField(controller: _instructionsController),
                  const SizedBox(height: 24),
                  QuantitySelector(
                    quantity: _quantity,
                    onDecrement: () {
                      if (_quantity > 1) setState(() => _quantity--);
                    },
                    onIncrement: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
          ),
          AddToCartBar(
            isBlocked: restaurantClosed || isLoadingOptions,
            isValid: _firstInvalidIndex() == null,
            restaurantClosed: restaurantClosed,
            total: _buildCartItem().totalPrice,
            onPressed: () => _handleAddToCartTap(l10n),
          ),
        ],
      ),
    );
  }
}
