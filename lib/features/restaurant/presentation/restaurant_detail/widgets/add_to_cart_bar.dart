import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';

/// The white bar at the bottom of the food sheet with the big
/// "Ajouter au panier • 18,500 DT" button. The button looks faded while
/// required choices are missing, and is disabled while the options load or
/// when the restaurant is closed (then it says so).
class AddToCartBar extends StatelessWidget {
  final bool isBlocked;
  final bool isValid;
  final bool restaurantClosed;
  final double total;
  final VoidCallback onPressed;

  const AddToCartBar({
    super.key,
    required this.isBlocked,
    required this.isValid,
    required this.restaurantClosed,
    required this.total,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isBlocked ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isValid ? AppColors.foodPrimary : AppColors.foodPrimary.withValues(alpha: 0.4),
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: AppColors.foodPrimary.withValues(alpha: 0.4),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            restaurantClosed
                ? l10n.restaurantClosedLabel
                : l10n.addToCartWithTotal(CurrencyFormatter.formatPrice(total)),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
