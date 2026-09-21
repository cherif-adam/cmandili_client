import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/vendor.dart';
import '../../../core/providers/vendor_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/venue_hours.dart';
import 'vendor_detail_screen.dart';

/// Shop list for any vendor category — florists, pet shops, gift shops,
/// bakeries, electronics stores.
///
/// One screen serves every category: the only thing that changes is the
/// `category` string it is given. That is the payoff of the generic vendors
/// table — a new category needs a database row, not another copy of this
/// file.
class VendorListScreen extends ConsumerWidget {
  /// `vendors.category` value to list.
  final String category;

  /// Shown in the empty state so it reads naturally per category
  /// ("Aucun fleuriste disponible").
  final String emptyLabel;

  const VendorListScreen({
    super.key,
    required this.category,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(vendorsByCategoryProvider(category));

    return vendorsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 40, color: AppColors.textLight),
              const SizedBox(height: 10),
              const Text(
                'Impossible de charger les boutiques',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(vendorsByCategoryProvider(category)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (vendors) {
        if (vendors.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Column(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 48, color: AppColors.textLight),
                  const SizedBox(height: 12),
                  Text(
                    emptyLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Revenez bientôt — de nouvelles boutiques arrivent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textLight, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          sliver: SliverList.separated(
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _VendorCard(vendor: vendors[i]),
          ),
        );
      },
    );
  }
}

/// One shop in the list. Deliberately the same shape for every category so a
/// customer moving between flowers and pet supplies is not relearning the UI.
class _VendorCard extends StatelessWidget {
  final Vendor vendor;

  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    // A closed shop still shows, greyed, with the time it opens — hiding it
    // makes the category look empty in the early morning.
    final opensAt = vendor.isOpen ? null : nextOpeningLabel(vendor.openingTime);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorDetailScreen(vendor: vendor),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: vendor.imageUrl.isEmpty
                        ? Container(
                            color: AppColors.background,
                            child: const Icon(Icons.storefront_rounded,
                                size: 40, color: AppColors.textLight),
                          )
                        : CachedNetworkImage(
                            imageUrl: vendor.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.background),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.background,
                              child: const Icon(Icons.storefront_rounded,
                                  size: 40, color: AppColors.textLight),
                            ),
                          ),
                  ),
                  // Dim closed shops rather than hiding them.
                  if (!vendor.isOpen)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Text(
                          opensAt ?? 'Fermé',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (vendor.isNew)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Nouveau',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vendor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (vendor.rating > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 17, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Text(
                          vendor.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (vendor.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      vendor.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        '${vendor.deliveryTime} min',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.delivery_dining_rounded,
                          size: 15, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        vendor.deliveryFee <= 0
                            ? 'Gratuit'
                            : CurrencyFormatter.formatPrice(vendor.deliveryFee),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
