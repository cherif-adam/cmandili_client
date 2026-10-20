import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// Green "🎉 Livraison gratuite appliquée — merci de votre fidélité !"
/// (or "-50 %") on a delivered order that used the loyalty discount.
class LoyaltyAppliedBanner extends StatelessWidget {
  /// 'free' or 'half'.
  final String milestoneType;

  const LoyaltyAppliedBanner({super.key, required this.milestoneType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              milestoneType == 'free'
                  ? AppLocalizations.of(context)!.loyaltyAppliedFree
                  : AppLocalizations.of(context)!.loyaltyAppliedHalf,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
