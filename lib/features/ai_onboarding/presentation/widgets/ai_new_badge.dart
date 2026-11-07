import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// The small "Nouveau" pill in the AI gradient, next to the ✦ of the home
/// search bar. Shown until the first AI search (AiOnboardingState.showNewBadge).
class AiNewBadge extends StatelessWidget {
  const AiNewBadge({super.key, this.fontSize = 10});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: AppColors.aiGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppLocalizations.of(context)!.aiNewBadge,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
