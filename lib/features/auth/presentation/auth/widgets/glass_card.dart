import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// The clean white card holding the login form, with a soft warm shadow.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double screenWidth;
  final double screenHeight;

  const GlassCard({
    super.key,
    required this.child,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.07),
        border: Border.all(
          color: AppColors.splashAmber.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.splashOrange.withValues(alpha: 0.12),
            blurRadius: screenWidth * 0.08,
            offset: Offset(0, screenHeight * 0.012),
          ),
        ],
      ),
      child: child,
    );
  }
}
