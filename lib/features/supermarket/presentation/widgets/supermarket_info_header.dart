import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/delivery_fee.dart';
import '../../data/models/supermarket.dart';

/// Under a supermarket's photo: name, description, and three coloured
/// pills — ★ rating · 🕒 time · 🛵 fee.
class SupermarketInfoHeader extends StatelessWidget {
  final Supermarket supermarket;

  const SupermarketInfoHeader({super.key, required this.supermarket});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supermarket.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            supermarket.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoPill(
                icon: Icons.star,
                label: '${supermarket.rating}',
                color: AppColors.star,
              ),
              const SizedBox(width: 12),
              _InfoPill(
                icon: Icons.access_time,
                label: '${supermarket.deliveryTime} min',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 12),
              _InfoPill(
                icon: Icons.delivery_dining,
                // Platform flat rate, not the venue's own delivery_fee
                // column — that column is unused for pricing and is 0 for
                // most stores.
                label: CurrencyFormatter.formatPrice(kFlatDeliveryFee),
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A light pill of [color]: icon + bold label.
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color.lerp(color, Colors.transparent, 0.9)!,
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
}
