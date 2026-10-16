import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/vendor.dart';
import '../../../../core/providers/nearby_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/delivery_fee.dart';
import '../../../../core/utils/venue_hours.dart';
import '../vendor_detail_screen.dart';

/// One shop in the florist / pet shop / gift / bakery / electronics list.
/// Deliberately the same shape for every category. Opens the shop's page.
///
///   Column
///   ├─ _VendorPhoto   132 px, dimmed with "Ouvre à…" when closed, "Nouveau"
///   └─ _VendorInfo    name ★ rating, description, 🕒 time 🛵 fee ➤ distance
class VendorCard extends ConsumerWidget {
  final Vendor vendor;

  const VendorCard({super.key, required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = ref.watch(shopDistanceLabelProvider(
        (lat: vendor.latitude, lng: vendor.longitude)));

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
            _VendorPhoto(vendor: vendor),
            _VendorInfo(vendor: vendor, distance: distance),
          ],
        ),
      ),
    );
  }
}

/// The shop's photo. A closed shop still shows, dimmed, with the time it
/// opens — hiding it makes the category look empty in the early morning.
class _VendorPhoto extends StatelessWidget {
  final Vendor vendor;

  const _VendorPhoto({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final opensAt = vendor.isOpen ? null : nextOpeningLabel(vendor.openingTime);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }
}

/// Under the photo:
///   name ................ ★ 4.8
///   description
///   🕒 40 min   🛵 3,50 DT   ➤ 1,4 km
class _VendorInfo extends StatelessWidget {
  final Vendor vendor;

  /// "1,4 km", or null while the customer's position is unknown.
  final String? distance;

  const _VendorInfo({required this.vendor, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                // Platform base fee — see vendor_detail_screen.
                CurrencyFormatter.formatPrice(kDeliveryBaseFee),
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
              if (distance != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.near_me_rounded,
                    size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  distance!,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
