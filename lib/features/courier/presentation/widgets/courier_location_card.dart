import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../checkout/data/models/delivery_address.dart';

/// A white tappable card for the pickup / delivery address: colored round
/// icon (or a spinner while locating), label + address, chevron.
class CourierLocationCard extends StatelessWidget {
  final String label;
  final DeliveryAddress? address;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double screenWidth;
  final double screenHeight;
  final bool isLoading;

  const CourierLocationCard({
    super.key,
    required this.label,
    required this.address,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.screenWidth,
    required this.screenHeight,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(w * 0.04),
      child: Container(
        padding: EdgeInsets.all(w * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(
            color: address != null
                ? color.withValues(alpha: 0.4)
                : Colors.grey.shade300,
            width: address != null ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.025),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? SizedBox(
                      width: w * 0.06,
                      height: w * 0.06,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon, color: color, size: w * 0.06),
            ),
            SizedBox(width: w * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: w * 0.032, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: h * 0.004),
                  Text(
                    address?.fullAddress ?? 'Appuyez pour sélectionner',
                    style: TextStyle(
                      fontSize: w * 0.038,
                      fontWeight: FontWeight.w600,
                      color: address != null
                          ? AppColors.textPrimary
                          : Colors.grey.shade400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
