import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// The big green "Se connecter" / "Créer un compte" button; a white spinner
/// while the request runs (and it can't be tapped).
class AuthSubmitButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;
  final double screenWidth;
  final double screenHeight;

  const AuthSubmitButton({
    super.key,
    required this.isLoading,
    required this.label,
    required this.onPressed,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: screenHeight * 0.06,
      child: ElevatedButton(
        key: const Key('auth_submit'),
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.04),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: screenHeight * 0.025,
                width: screenHeight * 0.025,
                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.042,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
