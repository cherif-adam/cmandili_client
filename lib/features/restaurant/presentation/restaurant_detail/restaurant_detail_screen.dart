import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../home/data/models/restaurant.dart';
import '../../data/models/food_item.dart';
import '../../providers/restaurant_provider.dart';
import 'restaurant_detail_controller.dart';
import 'widgets/food_item_card.dart';
import 'widgets/menu_category_chips.dart';
import 'widgets/restaurant_detail_app_bar.dart';
import 'widgets/restaurant_info_header.dart';
import 'widgets/view_cart_button.dart';

/// A restaurant's page, top to bottom:
///
///   RestaurantDetailAppBar   photo, back, favourite, share
///   RestaurantInfoHeader     name, description, rating / time / fee
///   MenuCategoryChips        Tout · Pizzas · Salades… (stays pinned)
///   list of FoodItemCard
///   ViewCartButton           floating, once the cart has something
///
/// UI only: the selected category, the category list and the filtering
/// live in [RestaurantDetailController]; the dishes come from
/// [foodItemsProvider] (ShopRepository behind it).
class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
  });

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  /// This page's own controller (see [restaurantDetailControllerProvider]).
  late final _provider = restaurantDetailControllerProvider(Object());
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuItemsAsync = ref.watch(foodItemsProvider(widget.restaurant.id));
    final selectedCategory = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    return menuItemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppLocalizations.of(context)!.errorLoadingMenu)),
      ),
      data: (menuItems) => Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            RestaurantDetailAppBar(restaurant: widget.restaurant),

            SliverToBoxAdapter(
              child: RestaurantInfoHeader(restaurant: widget.restaurant),
            ),

            _CategoryChipsHeader(
              categories: controller.categoriesOf(menuItems),
              selected: selectedCategory,
              onSelected: controller.selectCategory,
            ),

            _MenuList(
              items: controller.visibleItems(menuItems),
              isOpen: widget.restaurant.isOpen,
            ),
          ],
        ),
        floatingActionButton: const ViewCartButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// The category chips. Stays at the top of the screen while the menu
/// scrolls under it.
class _CategoryChipsHeader extends StatelessWidget {
  const _CategoryChipsHeader({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHeader(
        height: 60,
        child: MenuCategoryChips(
          categories: categories,
          selected: selected,
          onSelected: onSelected,
        ),
      ),
    );
  }
}

/// One FoodItemCard per dish of the selected category.
class _MenuList extends StatelessWidget {
  const _MenuList({required this.items, required this.isOpen});

  final List<FoodItem> items;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => FoodItemCard(
            foodItem: items[index],
            isOpen: isOpen,
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

/// Keeps [child] pinned at a fixed [height] at the top of the scroll view.
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedHeader({required this.height, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
