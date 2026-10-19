import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/models/vendor.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/delivery_fee.dart';

/// Under the shop's photo:
///   name
///   description
///   ★ 4.8 (33)   🕒 40 min   🛵 3,50 DT
///   [Cette boutique est actuellement fermée.]   (only when closed)
class VendorInfoHeader extends StatelessWidget {
  final Vendor vendor;

  const VendorInfoHeader({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vendor.name,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          if (vendor.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              vendor.description,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                // Platform base fee, not vendors.delivery_fee — that column
                // is 0 for every vendor, while checkout charges the
                // distance-based fee. Same fix as restaurant_card.dart.
                CurrencyFormatter.formatPrice(kDeliveryBaseFee),
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
              child: Text(
                AppLocalizations.of(context)!.vendorClosedNotice,
                style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
