import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/platform_pricing.dart';
import '../../home/data/models/restaurant.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../data/models/food_item.dart';
import '../providers/restaurant_provider.dart';
import 'widgets/food_item_customization_sheet.dart';

// Real food items loaded from Supabase via foodItemsProvider

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
        body: Center(child: Text('Error loading menu: $e')),
      ),
      data: (menuItems) => _buildScaffold(context, menuItems),
    );
  }

  Widget _buildScaffold(BuildContext context, List<FoodItem> menuItems) {
    final categories = ['All', ...menuItems.map((e) => e.category).toSet()];

    final filteredItems = _selectedCategory == 'All'
        ? menuItems
        : menuItems.where((item) => item.category == _selectedCategory).toList();

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar with Parallax Image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.background,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final isFav = ref.watch(isFavoriteProvider(widget.restaurant.id));
                  return Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? AppColors.error : Colors.black,
                      ),
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(widget.restaurant);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFav ? AppLocalizations.of(context)!.removedFromFavorites : AppLocalizations.of(context)!.addedToFavorites,
                            ),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.black),
                  onPressed: () {
                    Share.share(
                      'Check out ${widget.restaurant.name}!\n'
                      '${widget.restaurant.description}\n'
                      'Rating: ${widget.restaurant.rating} ⭐\n'
                      'Delivery: ${widget.restaurant.deliveryTime} min',
                      subject: widget.restaurant.name,
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Hero(
                tag: 'restaurant_image_${widget.restaurant.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    (widget.restaurant.imageUrl.isNotEmpty && widget.restaurant.imageUrl.startsWith('http'))
                      ? CachedNetworkImage(
                          imageUrl: widget.restaurant.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.background,
                          child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                        ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Restaurant Info
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              transform: Matrix4.translationValues(0, -20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.restaurant.name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.restaurant.description,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          Icons.star_rounded,
                          '${widget.restaurant.rating}',
                          '${widget.restaurant.reviewCount} reviews',
                          AppColors.star,
                        ),
                        _buildDivider(),
                        _buildStat(
                          Icons.access_time_filled,
                          '${widget.restaurant.deliveryTime} min',
                          'Delivery time',
                          AppColors.foodPrimary,
                        ),
                        _buildDivider(),
                        _buildStat(
                          Icons.delivery_dining,
                          CurrencyFormatter.formatPrice(widget.restaurant.deliveryFee),
                          'Delivery fee',
                          AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Sticky Category Header
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              child: Container(
                height: 60,
                color: AppColors.background,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories.elementAt(index);
                    final isSelected = category == _selectedCategory;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.foodPrimary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : AppColors.textLight.withValues(alpha: 0.2),
                            ),
                          ),
                          elevation: isSelected ? 4 : 0,
                          shadowColor: AppColors.foodPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Menu Items
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = filteredItems[index];
                  return _FoodItemCard(
                    foodItem: item,
                    isOpen: widget.restaurant.isOpen,
                  );
                },
                childCount: filteredItems.length,
              ),
            ),
          ),
        ],
      ),
      
      // Floating Cart Button (if items in cart)
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final cartItemCount = ref.watch(cartItemCountProvider);
          final cartTotal = ref.watch(cartTotalProvider);
          
          if (cartItemCount == 0) return const SizedBox.shrink();
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            width: double.infinity,
            child: FloatingActionButton.extended(
              onPressed: () {
                // Navigate directly to cart screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
              backgroundColor: AppColors.foodPrimary,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              label: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartItemCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'View Cart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    CurrencyFormatter.formatPrice(cartTotal),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppColors.textLight.withValues(alpha: 0.2),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class _FoodItemCard extends ConsumerWidget {
  final FoodItem foodItem;
  // Open/closed state of the parent restaurant — gates add-to-cart (P0).
  final bool isOpen;

  const _FoodItemCard({required this.foodItem, required this.isOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFoodItemDialog(context, ref, foodItem),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Food Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: (foodItem.imageUrl.isNotEmpty && foodItem.imageUrl.startsWith('http'))
                    ? CachedNetworkImage(
                        imageUrl: foodItem.imageUrl,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.background,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.background,
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 110,
                        height: 110,
                        color: AppColors.background,
                        child: const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                ),
                
                const SizedBox(width: 16),
                
                // Food Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              foodItem.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (foodItem.isVegetarian)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.eco,
                                size: 16,
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        foodItem.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Builder(builder: (context) {
                        final hhActive = foodItem.discountPrice != null &&
                            foodItem.discountEndTime != null &&
                            foodItem.discountEndTime!.isAfter(DateTime.now());
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: hhActive
                                  ? Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF9500),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'HH',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          CurrencyFormatter.formatPrice(foodItem.clientPrice),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFF9500),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            CurrencyFormatter.formatPrice(applyPlatformMarkup(foodItem.price)),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      CurrencyFormatter.formatPrice(foodItem.clientPrice),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.foodPrimary,
                                      ),
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.foodPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: AppColors.foodPrimary,
                                size: 20,
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFoodItemDialog(BuildContext context, WidgetRef ref, FoodItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodItemCustomizationSheet(item: item, isOpen: isOpen),
    );
  }
}
