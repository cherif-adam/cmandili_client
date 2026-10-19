import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// The green bar at the top of the orders tab: "3/5 commandes avant votre
/// prochaine réduction". Counts within the current 5-order cycle; back to
/// 0/5 right after a milestone (5th / 10th) order is delivered.
class LoyaltyProgressCard extends StatelessWidget {
  /// Delivered orders so far.
  final int count;
  final double sw;
  final double sh;

  const LoyaltyProgressCard({
    super.key,
    required this.count,
    required this.sw,
    required this.sh,
  });

  @override
  Widget build(BuildContext context) {
    final progressInCycle = count % 5;
    return Container(
      margin: EdgeInsets.only(bottom: sh * 0.015),
      padding: EdgeInsets.all(sw * 0.04),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(sw * 0.04),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, color: AppColors.primary, size: sw * 0.06),
          SizedBox(width: sw * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!
                      .loyaltyProgressOrders('$progressInCycle'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: sw * 0.035,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: sh * 0.004),
                ClipRRect(
                  borderRadius: BorderRadius.circular(sw * 0.02),
                  child: LinearProgressIndicator(
                    value: progressInCycle / 5,
                    minHeight: sh * 0.008,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
