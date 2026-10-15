import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'courier_colors.dart';

/// A section title of the "Colis" page: purple icon + bold title.
class CourierSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final double screenWidth;

  const CourierSectionHeader(
    this.title,
    this.icon, {
    super.key,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    return Row(
      children: [
        Icon(icon, color: kCourierPurple, size: w * 0.055),
        SizedBox(width: w * 0.02),
        Text(
          title,
          style: TextStyle(
            fontSize: w * 0.042,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
