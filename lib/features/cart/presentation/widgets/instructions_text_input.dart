import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// The 4-line card where the customer types instructions.
class InstructionsTextInput extends StatelessWidget {
  final TextEditingController controller;
  final double screenWidth;
  final double screenHeight;

  const InstructionsTextInput({
    super.key,
    required this.controller,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, screenHeight * 0.006),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: 4,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: screenWidth * 0.04,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.typeInstructionsHint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: screenWidth * 0.038,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.all(screenWidth * 0.05),
        ),
      ),
    );
  }
}
