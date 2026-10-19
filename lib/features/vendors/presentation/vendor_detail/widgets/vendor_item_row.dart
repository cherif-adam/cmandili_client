import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/models/vendor.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/widgets/new_item_badge.dart';
import '../../../../cart/data/models/cart_item.dart';
import '../../../../cart/presentation/add_to_cart_guard.dart';

/// One product in a shop's catalogue:
///
///   Row
///   ├─ 74×74 photo
///   ├─ Column: name · NOUVEAU, description, price (old price crossed out) / unit
///   └─ green "+" button: adds it to the cart
///
/// Greyed out and not addable while the shop is closed ([enabled] false).
class VendorItemRow extends ConsumerWidget {
  final VendorItem item;
  final bool enabled;

  const VendorItemRow({super.key, required this.item, required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ItemPhoto(imageUrl: item.imageUrl),
              const SizedBox(width: 12),
              Expanded(child: _ItemDetails(item: item)),
              const SizedBox(width: 6),
              IconButton(
                onPressed: enabled ? () => _addToCart(context, ref) : null,
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

  Future<void> _addToCart(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Même règle que partout ailleurs : un panier appartient à une seule
    // boutique, sinon la commande part au mauvais commerçant.
    final added =
        await addToCartGuarded(context, ref, CartItem.vendor(vendorItem: item));
    if (!added) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.addedToCart(item.name)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// The 74×74 product photo, or an image icon when there is none.
class _ItemPhoto extends StatelessWidget {
  final String imageUrl;

  const _ItemPhoto({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 74,
        height: 74,
        child: imageUrl.isEmpty
            ? Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const Icon(Icons.image_outlined, color: AppColors.textLight),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Icon(Icons.image_outlined,
                      color: AppColors.textLight),
                ),
              ),
      ),
    );
  }
}

/// Name · NOUVEAU, description, then price — old price crossed out during
/// a promotion — and the unit ("/ kg").
class _ItemDetails extends StatelessWidget {
  final VendorItem item;

  const _ItemDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final discounted = item.hasActiveDiscount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ),
            if (item.isNew) ...[
              const SizedBox(width: 6),
              const NewItemBadge(),
            ],
          ],
        ),
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
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
                style: const TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
