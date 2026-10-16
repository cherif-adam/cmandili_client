import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// The "Commander un repas" photo banner at the top of the restaurant list.
class FoodHeroBanner extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const FoodHeroBanner({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.01,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 110,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/amana_food_hero.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15),
                errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.orangeBannerGradient),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)!.foodHeroTitle,
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
      ),
    );
  }
}
