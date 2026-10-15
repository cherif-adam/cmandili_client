import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A square white button with a provider logo (e.g. Google's "G").
class SocialSignInButton extends StatelessWidget {
  final IconData icon;

  /// Null disables it (while a sign-in is running).
  final VoidCallback? onPressed;
  final double screenWidth;
  final double screenHeight;

  const SocialSignInButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.045),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppColors.textLight.withValues(alpha: 0.25),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(screenWidth * 0.04),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: screenWidth * 0.02,
                offset: Offset(0, screenHeight * 0.005),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: screenWidth * 0.08,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
