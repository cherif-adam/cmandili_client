import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/platform_pricing.dart';
import '../../../cart/data/models/cart_item.dart';
import '../../../cart/data/models/order_customization.dart';
import '../../../cart/data/models/selected_option_group.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../menu/data/models/item_variant.dart';
import '../../../menu/data/models/food_item_option_group.dart';
import '../../data/models/food_item.dart';
import '../../providers/restaurant_provider.dart';

/// Bottom sheet shown when a customer taps a food item: image/name/price,
/// then any variants ("Type au choix") and option groups ("Sauce au choix",
/// "Suppléments", ...), special instructions, quantity, and Add to Cart.
/// Items with neither variants nor option groups render the same sheet with
/// no group sections — the group list is simply empty, so this looks and
/// behaves exactly like the pre-customization dialog.
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

/// One row in the unified group list — either the single "Type au choix"
/// variants slot (key == _variantGroupKey) or a real option group (key ==
/// its DB id). Unifying the two here keeps rendering/validation generic;
/// the data layer keeps variants and option groups as separate lists.
class _DisplayGroup {
  final String key;
  final String title;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;
  final List<_DisplayOption> options;

  const _DisplayGroup({
    required this.key,
    required this.title,
    required this.minSelections,
    required this.maxSelections,
    required this.isRequired,
    required this.options,
  });
}

class _DisplayOption {
  final String id;
  final String name;
  final double price; // raw, pre-markup

  const _DisplayOption({
    required this.id,
    required this.name,
    required this.price,
  });
}

const _variantGroupKey = 'variant';

class _FoodItemCustomizationSheetState
    extends ConsumerState<FoodItemCustomizationSheet> {
  int _quantity = 1;
  final Map<String, Set<String>> _selections = {};
  List<_DisplayGroup> _displayGroups = const [];
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
    final groups = <_DisplayGroup>[];
    if (data.variants.isNotEmpty) {
      groups.add(_DisplayGroup(
        key: _variantGroupKey,
        title: l10n.variantGroupTitle,
        minSelections: 1,
        maxSelections: 1,
        isRequired: true,
        options: data.variants
            .map((v) => _DisplayOption(id: v.id, name: v.name, price: v.price))
            .toList(),
      ));
    }
    for (final g in data.optionGroups) {
      if (g.options.isEmpty) continue; // no purchasable option -> don't block the item
      groups.add(_DisplayGroup(
        key: g.id,
        title: g.name,
        minSelections: g.minSelections,
        maxSelections: g.maxSelections,
        isRequired: g.isRequired,
        options: g.options
            .map((o) => _DisplayOption(id: o.id, name: o.name, price: o.price))
            .toList(),
      ));
    }
    _displayGroups = groups;
    _groupKeys = List.generate(groups.length, (_) => GlobalKey());
  }

  void _toggleOption(_DisplayGroup group, _DisplayOption option) {
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

  bool _isGroupSatisfied(_DisplayGroup group) {
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

  void _handleAddToCartTap(AppLocalizations l10n) {
    final invalidIndex = _firstInvalidIndex();
    if (invalidIndex != null) {
      _scrollToAndHighlight(invalidIndex, l10n);
      return;
    }
    final cartItem = _buildCartItem();
    ref.read(cartProvider.notifier).addItem(cartItem);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_quantity x ${widget.item.name} added to cart'),
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
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: (widget.item.imageUrl.isNotEmpty &&
                            widget.item.imageUrl.startsWith('http'))
                        ? CachedNetworkImage(
                            imageUrl: widget.item.imageUrl,
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.background,
                              child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: 250,
                            color: AppColors.background,
                            child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.name,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        CurrencyFormatter.formatPrice(widget.item.clientPrice),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foodPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.item.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  for (var i = 0; i < _displayGroups.length; i++) ...[
                    _buildGroupSection(context, i, l10n),
                  ],

                  Text(
                    l10n.specialInstructions,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _instructionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.typeInstructionsHint,
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (_quantity > 1) setState(() => _quantity--);
                              },
                              icon: const Icon(Icons.remove),
                              color: AppColors.textPrimary,
                            ),
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _quantity++),
                              icon: const Icon(Icons.add),
                              color: AppColors.foodPrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Builder(builder: (context) {
              final blocked = restaurantClosed || isLoadingOptions;
              final isValid = _firstInvalidIndex() == null;
              final total = _buildCartItem().totalPrice;
              return SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: blocked
                      ? null
                      : () => _handleAddToCartTap(l10n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isValid ? AppColors.foodPrimary : AppColors.foodPrimary.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: AppColors.foodPrimary.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    restaurantClosed
                        ? 'Restaurant fermé'
                        : l10n.addToCartWithTotal(CurrencyFormatter.formatPrice(total)),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(BuildContext context, int index, AppLocalizations l10n) {
    final group = _displayGroups[index];
    final selected = _selections[group.key] ?? const <String>{};
    final highlighted = _highlightedGroupIndex == index;

    final String helperText;
    if (group.minSelections == group.maxSelections) {
      helperText = l10n.optionGroupSelectExact(group.minSelections);
    } else if (group.minSelections == 0) {
      helperText = l10n.optionGroupSelectUpTo(group.maxSelections);
    } else {
      helperText = l10n.optionGroupSelectRange(group.minSelections, group.maxSelections);
    }

    return AnimatedContainer(
      key: _groupKeys[index],
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.error.withValues(alpha: 0.06) : Colors.transparent,
        border: Border.all(
          color: highlighted ? AppColors.error : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: group.isRequired
                      ? AppColors.foodPrimary.withValues(alpha: 0.12)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  group.isRequired ? l10n.optionGroupRequired : l10n.optionGroupOptional,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: group.isRequired ? AppColors.foodPrimaryDark : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 13,
              color: highlighted ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final option in group.options)
            _OptionRow(
              name: option.name,
              price: option.price,
              isSelected: selected.contains(option.id),
              isSingleSelect: group.maxSelections == 1,
              onTap: () => _toggleOption(group, option),
            ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String name;
  final double price;
  final bool isSelected;
  final bool isSingleSelect;
  final VoidCallback onTap;

  const _OptionRow({
    required this.name,
    required this.price,
    required this.isSelected,
    required this.isSingleSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrice = applyPlatformMarkup(price);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isSingleSelect
                  ? (isSelected ? Icons.radio_button_checked : Icons.radio_button_off)
                  : (isSelected ? Icons.check_box : Icons.check_box_outline_blank),
              color: isSelected ? AppColors.foodPrimary : AppColors.textLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              displayPrice > 0
                  ? '+${CurrencyFormatter.formatPrice(displayPrice)}'
                  : CurrencyFormatter.formatPrice(displayPrice),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: displayPrice > 0 ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
