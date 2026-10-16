import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../cart/providers/cart_provider.dart';
import '../data/models/grocery_category.dart';
import '../data/models/supermarket.dart';
import '../providers/supermarket_provider.dart';
import 'widgets/grocery_category_chips.dart';
import 'widgets/grocery_product_card.dart';
import 'widgets/supermarket_cart_button.dart';
import 'widgets/supermarket_detail_app_bar.dart';
import 'widgets/supermarket_info_header.dart';

/// A supermarket's page, top to bottom:
///
///   SupermarketDetailAppBar   photo, back
///   SupermarketInfoHeader     name, description, rating / time / fee
///   GroceryCategoryChips      Tout · Légumes · Fruits…
///   grid of GroceryProductCard (2 per row)
///   SupermarketCartButton     floating, once the cart has something
class SupermarketDetailScreen extends ConsumerStatefulWidget {
  final Supermarket supermarket;

  const SupermarketDetailScreen({
    super.key,
    required this.supermarket,
  });

  @override
  ConsumerState<SupermarketDetailScreen> createState() => _SupermarketDetailScreenState();
}

class _SupermarketDetailScreenState extends ConsumerState<SupermarketDetailScreen> {
  /// Null = "Tout".
  GroceryCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final groceryItemsAsync = ref.watch(groceryItemsProvider(widget.supermarket.id));
    final cartItemCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      body: groceryItemsAsync.when(
        data: (groceryItems) {
          final filteredItems = _selectedCategory == null
              ? groceryItems
              : groceryItems.where((item) => item.category == _selectedCategory).toList();

          return CustomScrollView(
            slivers: [
              SupermarketDetailAppBar(supermarket: widget.supermarket),
              SliverToBoxAdapter(
                child: SupermarketInfoHeader(supermarket: widget.supermarket),
              ),
              SliverToBoxAdapter(
                child: GroceryCategoryChips(
                  selected: _selectedCategory,
                  onChanged: (category) =>
                      setState(() => _selectedCategory = category),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => GroceryProductCard(
                      item: filteredItems[index],
                      isOpen: widget.supermarket.isOpen,
                    ),
                    childCount: filteredItems.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(AppLocalizations.of(context)!.errorLoadingItems),
        ),
      ),
      floatingActionButton: cartItemCount > 0
          ? SupermarketCartButton(cartItemCount: cartItemCount)
          : null,
    );
  }
}
