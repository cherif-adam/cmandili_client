import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/delivery_fee.dart';
import '../../../../home/data/models/restaurant.dart';

/// The white card with three columns on a restaurant's page:
///   ★ 4.6 / 214 avis  |  🕒 25 min / Temps de livraison  |  🛵 3,50 DT / Frais
class RestaurantStatsCard extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantStatsCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          _Stat(
            icon: Icons.star_rounded,
            value: '${restaurant.rating}',
            label: l.reviewsCount(restaurant.reviewCount),
            color: AppColors.star,
          ),
          const _StatDivider(),
          _Stat(
            icon: Icons.access_time_filled,
            value: '${restaurant.deliveryTime} min',
            label: l.deliveryTimeLabel,
            color: AppColors.foodPrimary,
          ),
          const _StatDivider(),
          _Stat(
            icon: Icons.delivery_dining,
            // restaurant.deliveryFee reads the DB's now-dead
            // restaurants.delivery_fee column (0 for every restaurant; the
            // fee is distance-based, see delivery_fee.dart). Show the real
            // base fee instead of a stale zero.
            value: CurrencyFormatter.formatPrice(kDeliveryBaseFee),
            label: l.deliveryFee,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

/// Icon, value in bold, label in grey — one column of the card.
class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// The thin vertical line between two columns.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: AppColors.textLight.withValues(alpha: 0.2),
    );
  }
}
