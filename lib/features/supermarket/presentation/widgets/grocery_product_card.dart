import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/new_item_badge.dart';
import '../../../cart/data/models/cart_item.dart';
import '../../../cart/presentation/add_to_cart_guard.dart';
import '../../data/models/grocery_item.dart';
import '../../providers/supermarket_provider.dart';
import 'grocery_variant_sheet.dart';

/// One product in a supermarket's grid:
///
///   photo (NOUVEAU / Bio badges)
///   name (2 lines), unit
///   price (old price crossed out during a promotion) ........ ⊕
///
/// The ⊕ adds it to the cart — via [GroceryVariantSheet] when the product
/// comes in several options.
class GroceryProductCard extends ConsumerWidget {
  final GroceryItem item;
  // Open/closed state of the parent supermarket — gates add-to-cart (P0).
  final bool isOpen;

  const GroceryProductCard({super.key, required this.item, required this.isOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          _ProductPhoto(item: item),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _ProductPrice(item: item)),
                      InkWell(
                        onTap: () => _addToCart(context, ref),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                                const Color(0xFF4CAF50), Colors.transparent, 0.9)!,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// If the item has variants the customer must pick one (bottom sheet);
  /// otherwise it is added directly with quantity 1.
  Future<void> _addToCart(BuildContext context, WidgetRef ref) async {
    // P0 ghost-order guard: block adding from a closed supermarket. This single
    // check covers BOTH the fast-add (no variants) and variant-picker paths.
    if (!isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.supermarketClosedNow),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final variants = await ref.read(groceryItemVariantsProvider(item.id).future);
    if (!context.mounted) return;

    if (variants.isEmpty) {
      final added = await addToCartGuarded(
          context, ref, CartItem.grocery(groceryItem: item, quantity: 1));
      if (!added || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.addedToCart(item.name)),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final picked = await showGroceryVariantSheet(context, item, variants);

    if (picked == null || !context.mounted) return;
    final added = await addToCartGuarded(context, ref,
        CartItem.grocery(groceryItem: item, quantity: 1, variant: picked));
    if (!added || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!
            .addedToCart('${item.name} — ${picked.name}')),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }
}

/// The 120 px product photo with its NOUVEAU (left) and Bio (right) badges.
class _ProductPhoto extends StatelessWidget {
  final GroceryItem item;

  const _ProductPhoto({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: (item.imageUrl.isNotEmpty && item.imageUrl.startsWith('http'))
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Icon(Icons.shopping_basket, size: 40, color: Colors.grey),
                  ),
                )
              : Container(
                  height: 120,
                  width: double.infinity,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Icon(Icons.shopping_basket, size: 40, color: Colors.grey),
                ),
        ),
        // On the photo rather than above the name: the card has a fixed
        // height and the text column has no room to spare.
        if (item.isNew) const Positioned(top: 8, left: 8, child: NewItemBadge()),
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
              child: Text(
                AppLocalizations.of(context)!.organic,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Green price, or orange promo price over the crossed-out normal price.
class _ProductPrice extends StatelessWidget {
  final GroceryItem item;

  const _ProductPrice({required this.item});

  @override
  Widget build(BuildContext context) {
    // No end date = runs until the shop stops it; the cart charges the
    // discount either way, so the menu must show it either way too.
    final hhActive = item.discountPrice != null &&
        (item.discountEndTime == null ||
            item.discountEndTime!.isAfter(DateTime.now()));

    if (!hhActive) {
      return Text(
        CurrencyFormatter.formatPrice(item.clientPrice),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4CAF50),
        ),
      );
    }

    return Column(
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
          CurrencyFormatter.formatPrice(item.price),
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}
