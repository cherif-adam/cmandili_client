import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// "Restaurants populaires ........ Voir tout" above the restaurant list.
/// "Voir tout" clears the cuisine filter and the search.
class PopularRestaurantsHeader extends StatelessWidget {
  final VoidCallback onSeeAll;
  final double screenWidth;

  const PopularRestaurantsHeader({
    super.key,
    required this.onSeeAll,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Expanded: "Restaurants populaires" + "Voir tout" were
        // 14 px wider than a 411-wide phone.
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.popularRestaurants,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            AppLocalizations.of(context)!.seeAll,
            style: TextStyle(
              color: AppColors.foodPrimary,
              fontSize: screenWidth * 0.038,
            ),
          ),
        ),
      ],
    );
  }
}
