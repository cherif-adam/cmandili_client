import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:badges/badges.dart' as badges;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/platform_pricing.dart';
import '../data/models/supermarket.dart';
import '../data/models/grocery_category.dart';
import '../data/models/grocery_item.dart';
import '../providers/supermarket_provider.dart';
import '../../cart/data/models/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../menu/data/models/item_variant.dart';

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
              // App Bar with Image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: const Color(0xFF4CAF50),
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
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: widget.supermarket.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Supermarket Info
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.supermarket.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.supermarket.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.star,
                            '${widget.supermarket.rating}',
                            AppColors.star,
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.access_time,
                            '${widget.supermarket.deliveryTime} min',
                            const Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.delivery_dining,
                            CurrencyFormatter.formatPrice(widget.supermarket.deliveryFee),
                            AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Category Filter
              SliverToBoxAdapter(
                child: Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: GroceryCategory.values.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildCategoryChip(null, 'All', '🛒');
                      }
                      final category = GroceryCategory.values[index - 1];
                      return _buildCategoryChip(
                        category,
                        category.nameEn,
                        category.icon,
                      );
                    },
                  ),
                ),
              ),

              // Products Grid
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
                    (context, index) {
                      final item = filteredItems[index];
                      return _ProductCard(item: item);
                    },
                    childCount: filteredItems.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading items: $error'),
        ),
      ),
      floatingActionButton: cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
              backgroundColor: const Color(0xFF4CAF50),
              icon: badges.Badge(
                badgeContent: Text(
                  '$cartItemCount',
                  style: const TextStyle(color: Colors.white),
                ),
                child: const Icon(Icons.shopping_cart, color: Colors.white),
              ),
              label: const Text(
                'View Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color.lerp(color, Colors.transparent, 0.9)!, // Replaced withOpacity
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(GroceryCategory? category, String label, String icon) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF4CAF50),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final GroceryItem item;

  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              if (item.isOrganic)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Organic',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Product Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.unit,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Builder(builder: (context) {
                    final hhActive = item.discountPrice != null &&
                        item.discountEndTime != null &&
                        item.discountEndTime!.isAfter(DateTime.now());
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: hhActive
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      CurrencyFormatter.formatPrice(item.clientPrice),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF9500),
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.formatPrice(applyPlatformMarkup(item.price)),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  CurrencyFormatter.formatPrice(item.clientPrice),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                        ),
                      InkWell(
                        onTap: () => _addGroceryToCart(context, ref, item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color.lerp(const Color(0xFF4CAF50), Colors.transparent, 0.9)!, // Replaced withOpacity
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Adds a grocery item to the cart. If the item has variants the customer
  /// must pick one — opens a bottom sheet of choice chips. Otherwise adds
  /// directly with quantity 1, matching the legacy fast-add behaviour.
  Future<void> _addGroceryToCart(
    BuildContext context,
    WidgetRef ref,
    GroceryItem item,
  ) async {
    final variants = await ref.read(groceryItemVariantsProvider(item.id).future);

    if (variants.isEmpty) {
      ref.read(cartProvider.notifier).addItem(
            CartItem.grocery(groceryItem: item, quantity: 1),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} added to cart'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final picked = await showModalBottomSheet<ItemVariant>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose an option',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...variants.map((v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.radio_button_unchecked,
                        color: Color(0xFF4CAF50)),
                    title: Text(v.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      CurrencyFormatter.formatPrice(applyPlatformMarkup(v.price)),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                        fontSize: 15,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, v),
                  )),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    ref.read(cartProvider.notifier).addItem(
          CartItem.grocery(groceryItem: item, quantity: 1, variant: picked),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} — ${picked.name} added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }
}
