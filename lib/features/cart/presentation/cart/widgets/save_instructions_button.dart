import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// The full-width green "Enregistrer" button of the instructions sheet.
class SaveInstructionsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double screenWidth;
  final double screenHeight;

  const SaveInstructionsButton({
    super.key,
    required this.onPressed,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: screenHeight * 0.065,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.04),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.save,
          style: TextStyle(
            fontSize: screenWidth * 0.042,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
