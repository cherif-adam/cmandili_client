import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Icon + bold value + small grey label, at the bottom of a shop card:
///   🛵 3,50 DT        🛍 10,00 DT
///      Livraison         Commande min.
class ShopInfoItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final String label;
  final double screenWidth;

  const ShopInfoItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    required this.label,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: screenWidth * 0.05,
          color: iconColor,
        ),
        SizedBox(width: screenWidth * 0.02),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.035,
                color: valueColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
