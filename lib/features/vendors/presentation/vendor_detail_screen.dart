import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/vendor.dart';
import '../../../core/providers/vendor_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../cart/data/models/cart_item.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../cart/providers/cart_provider.dart';

/// Catalogue for one shop of any generic category.
///
/// Items are grouped by their in-shop section ("Roses", "Croquettes") so a
/// florist with fifty products is still browsable, and each row adds straight
/// to the shared cart — the same cart the food and grocery flows use, so
/// checkout needed no changes.
class VendorDetailScreen extends ConsumerWidget {
  final Vendor vendor;

  const VendorDetailScreen({super.key, required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(vendorItemsProvider(vendor.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: vendor.imageUrl.isEmpty
                  ? Container(
                      color: AppColors.background,
                      child: const Icon(Icons.storefront_rounded,
                          size: 56, color: AppColors.textLight),
                    )
                  : CachedNetworkImage(
                      imageUrl: vendor.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.background,
                        child: const Icon(Icons.storefront_rounded,
                            size: 56, color: AppColors.textLight),
                      ),
                    ),
            ),
          ),

          // Shop header
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  if (vendor.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      vendor.description,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (vendor.rating > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 18, color: AppColors.secondary),
                        const SizedBox(width: 3),
                        Text(
                          '${vendor.rating.toStringAsFixed(1)}'
                          '${vendor.reviewCount > 0 ? ' (${vendor.reviewCount})' : ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        const SizedBox(width: 14),
                      ],
                      const Icon(Icons.schedule_rounded,
                          size: 16, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text('${vendor.deliveryTime} min',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(width: 14),
                      const Icon(Icons.delivery_dining_rounded,
                          size: 17, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        vendor.deliveryFee <= 0
                            ? 'Gratuit'
                            : CurrencyFormatter.formatPrice(vendor.deliveryFee),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (!vendor.isOpen) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Cette boutique est actuellement fermée.',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          ...itemsAsync.when(
            loading: () => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            ],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 36, color: AppColors.textLight),
                      const SizedBox(height: 10),
                      const Text('Impossible de charger le catalogue',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(vendorItemsProvider(vendor.id)),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            ],
            data: (items) {
              if (items.isEmpty) {
                return [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Center(
                        child: Text(
                          'Aucun article pour le moment.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                ];
              }

              // Group by the item's section. A LinkedHashMap keeps the order
              // the rows came back in (sort_order), so the shop controls how
              // its catalogue reads.
              final grouped = <String, List<VendorItem>>{};
              for (final item in items) {
                final key = (item.category?.trim().isNotEmpty ?? false)
                    ? item.category!.trim()
                    : 'Articles';
                grouped.putIfAbsent(key, () => []).add(item);
              }

              return [
                for (final entry in grouped.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: entry.value.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _ItemRow(
                        item: entry.value[i],
                        enabled: vendor.isOpen,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ];
            },
          ),
        ],
      ),

      // Same floating cart bar the food and grocery catalogues use, so a
      // shop order is as obviously checkout-able as a restaurant one.
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
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
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Voir le panier',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    CurrencyFormatter.formatPrice(cartTotal),
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}

class _ItemRow extends ConsumerWidget {
  final VendorItem item;
  final bool enabled;

  const _ItemRow({required this.item, required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discounted = item.hasActiveDiscount;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: item.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.background,
                          child: const Icon(Icons.image_outlined,
                              color: AppColors.textLight),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.background,
                            child: const Icon(Icons.image_outlined,
                                color: AppColors.textLight),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.formatPrice(item.effectivePrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                        if (discounted) ...[
                          const SizedBox(width: 6),
                          Text(
                            CurrencyFormatter.formatPrice(item.price),
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textLight,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        if (item.unit != null && item.unit!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '/ ${item.unit}',
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: enabled
                    ? () {
                        ref
                            .read(cartProvider.notifier)
                            .addItem(CartItem.vendor(vendorItem: item));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('${item.name} ajouté au panier'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                      }
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textLight,
                  minimumSize: const Size(38, 38),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
