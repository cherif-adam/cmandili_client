import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../home/data/models/restaurant.dart';
import '../data/models/food_item.dart';
import '../providers/restaurant_provider.dart';
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
  String _selectedCategory = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuItemsAsync = ref.watch(foodItemsProvider(widget.restaurant.id));

    return menuItemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppLocalizations.of(context)!.errorLoadingMenu)),
      ),
      data: (menuItems) => _buildScaffold(menuItems),
    );
  }

  Widget _buildScaffold(List<FoodItem> menuItems) {
    final categories = ['All', ...menuItems.map((e) => e.category).toSet()];

    final filteredItems = _selectedCategory == 'All'
        ? menuItems
        : menuItems.where((item) => item.category == _selectedCategory).toList();

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          RestaurantDetailAppBar(restaurant: widget.restaurant),

          SliverToBoxAdapter(
            child: RestaurantInfoHeader(restaurant: widget.restaurant),
          ),

          // Stays at the top of the screen while the menu scrolls under it.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeader(
              height: 60,
              child: MenuCategoryChips(
                categories: categories,
                selected: _selectedCategory,
                onSelected: (category) =>
                    setState(() => _selectedCategory = category),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => FoodItemCard(
                  foodItem: filteredItems[index],
                  isOpen: widget.restaurant.isOpen,
                ),
                childCount: filteredItems.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const ViewCartButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
