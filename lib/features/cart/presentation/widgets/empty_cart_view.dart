import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// What the cart shows when it is empty: a cart icon, "Votre panier est
/// vide" and a button back to the restaurants.
class EmptyCartView extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const EmptyCartView({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.08),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: screenWidth * 0.2,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          Text(
            AppLocalizations.of(context)!.cartEmpty,
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            AppLocalizations.of(context)!.addItemsToGetStarted,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: screenWidth * 0.04,
            ),
          ),
          SizedBox(height: screenHeight * 0.04),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.02,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.04),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppLocalizations.of(context)!.browseRestaurants,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
