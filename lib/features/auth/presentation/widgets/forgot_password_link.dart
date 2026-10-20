import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../forgot_password/forgot_password_screen.dart';

/// "Forgot Password?" on the right, under the password (sign-in tab only).
class ForgotPasswordLink extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const ForgotPasswordLink({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ForgotPasswordScreen(),
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.01,
            vertical: screenHeight * 0.005,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: screenWidth * 0.037,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
