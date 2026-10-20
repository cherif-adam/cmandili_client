import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// The 110px photo banner at the top of the "Colis" page: green gradient,
/// white title and a mint subtitle.
class CourierHeroBanner extends StatelessWidget {
  final double screenWidth;

  const CourierHeroBanner({super.key, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 110,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/amana_colis_handover.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.4),
              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.emeraldBannerGradient),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sendParcelTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: w * 0.05,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.sendParcelSubtitle,
                    style: TextStyle(
                      color: AppColors.orderSuccessSubtitleMint,
                      fontSize: w * 0.032,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
