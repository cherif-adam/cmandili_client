import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// The small grey line under a section title ("La personne qui remet le
/// colis", "Optionnel — …").
class CourierSectionHint extends StatelessWidget {
  final String text;
  final double screenWidth;

  const CourierSectionHint(this.text, {super.key, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: screenWidth * 0.032, color: AppColors.textSecondary),
    );
  }
}
