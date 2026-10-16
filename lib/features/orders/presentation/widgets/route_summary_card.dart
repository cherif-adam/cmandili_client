import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/services/route_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Live route summary shown above the order timeline: traffic-aware ETA,
/// remaining driving distance, and the named streets the driver's current
/// route runs along. Rebuilt whenever the route is re-fetched, so if the
/// driver takes a different street the list here changes with the drawn line.
class RouteSummaryCard extends StatelessWidget {
  final AppRoute route;

  const RouteSummaryCard({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    // Enough streets to show the shape of the journey without turning the
    // card into a full turn-by-turn list, which the customer does not need.
    const maxStreets = 4;
    final streets = route.streetNames.take(maxStreets).toList();
    final remaining = route.streetNames.length - streets.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                route.etaLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${route.distanceLabel}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (streets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.routeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            // Streets in travel order, separated by chevrons so the sequence
            // reads as a path rather than an unordered set of names.
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < streets.length; i++) ...[
                  if (i > 0)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textLight.withValues(alpha: 0.8),
                    ),
                  Text(
                    streets[i],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (remaining > 0)
                  Text(
                    '+$remaining',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
