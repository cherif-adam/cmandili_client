import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// What the orders tab shows before the first order: a receipt icon,
/// "No orders yet" and a short hint.
class EmptyOrdersView extends StatelessWidget {
  final double sw;
  final double sh;

  const EmptyOrdersView({super.key, required this.sw, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(sw * 0.06),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: sw * 0.15,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: sh * 0.03),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: sw * 0.055,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: sh * 0.01),
          Text(
            'Your order history will appear here',
            style: TextStyle(
              fontSize: sw * 0.038,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
