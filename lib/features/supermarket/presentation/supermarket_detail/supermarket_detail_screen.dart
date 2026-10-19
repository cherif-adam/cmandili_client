import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../cart/providers/cart_provider.dart';
import '../../data/models/grocery_item.dart';
import '../../data/models/supermarket.dart';
import '../../providers/supermarket_provider.dart';
import 'supermarket_detail_controller.dart';
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
///
/// UI only: the selected category and the filtering live in
/// [SupermarketDetailController]; the items come from [groceryItemsProvider].
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
  /// This page's own controller (see [supermarketDetailControllerProvider]).
  late final _provider = supermarketDetailControllerProvider(Object());

  @override
  Widget build(BuildContext context) {
    final groceryItemsAsync = ref.watch(groceryItemsProvider(widget.supermarket.id));
    final cartItemCount = ref.watch(cartItemCountProvider);
    final selectedCategory = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    return Scaffold(
      body: groceryItemsAsync.when(
        data: (groceryItems) {
          final filteredItems = controller.visibleItems(groceryItems);

          return CustomScrollView(
            slivers: [
              SupermarketDetailAppBar(supermarket: widget.supermarket),
              SliverToBoxAdapter(
                child: SupermarketInfoHeader(supermarket: widget.supermarket),
              ),
              SliverToBoxAdapter(
                child: GroceryCategoryChips(
                  selected: selectedCategory,
                  onChanged: controller.selectCategory,
                ),
              ),
              _ProductGrid(
                items: filteredItems,
                isOpen: widget.supermarket.isOpen,
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

// ── Sections ──────────────────────────────────────────────────────────────────

/// Two GroceryProductCards per row.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.items, required this.isOpen});

  final List<GroceryItem> items;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
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
            item: items[index],
            isOpen: isOpen,
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}
