import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../widgets/service_selector.dart';

/// "Catégories" title + the grid of category tiles (Restaurants,
/// Supermarché, Pâtisserie, Fleurs… Colis, Facture).
class HomeCategoriesSection extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const HomeCategoriesSection({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    // The selector lays itself out from the width it is given, so the
    // horizontal padding lives here rather than inside it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.categories,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ServiceSelector(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
        ],
      ),
    );
  }
}
