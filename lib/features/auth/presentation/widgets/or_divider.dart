import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// "──── OU ────" between the form and the Google button.
class OrDivider extends StatelessWidget {
  final double screenWidth;

  const OrDivider({super.key, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.transparent, AppColors.textLight.withValues(alpha: 0.3)]),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Text(
            AppLocalizations.of(context)!.or,
            style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                fontSize: screenWidth * 0.035),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.textLight.withValues(alpha: 0.3), Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }
}
