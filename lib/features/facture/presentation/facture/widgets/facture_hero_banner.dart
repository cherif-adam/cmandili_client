import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// The 110px photo banner at the top of the "Facture" page, with the
/// green gradient and the white title on the left.
class FactureHeroBanner extends StatelessWidget {
  final double screenWidth;

  const FactureHeroBanner({super.key, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 110,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/amana_facture_hero.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.2),
              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.emeraldBannerGradient),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.factureHeroTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
