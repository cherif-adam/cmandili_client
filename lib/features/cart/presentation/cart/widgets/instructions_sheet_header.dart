import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// "Instructions spéciales" title with a × that closes the sheet.
class InstructionsSheetHeader extends StatelessWidget {
  final double screenWidth;

  const InstructionsSheetHeader({super.key, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLocalizations.of(context)!.specialInstructions,
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}
