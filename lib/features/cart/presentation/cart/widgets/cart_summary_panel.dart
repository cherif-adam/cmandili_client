import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../checkout/presentation/checkout/checkout_screen.dart';

/// The white panel at the bottom of the cart:
///
///   Sous-total ............ 36,00 DT
///   Frais de livraison ....  3,50 DT
///   ───────────────────────────────
///   Total ................. 39,50 DT
///   [ Passer à la caisse ]
class CartSummaryPanel extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;

  /// Extra space at the bottom for what floats over the cart (menu bar).
  final double bottomInset;
  final double screenWidth;
  final double screenHeight;

  const CartSummaryPanel({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.bottomInset,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final total = subtotal + deliveryFee;
    final l = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.06,
        screenWidth * 0.06,
        screenWidth * 0.06,
        screenWidth * 0.06 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(screenWidth * 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: screenWidth * 0.05,
            offset: Offset(0, -screenHeight * 0.006),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(
              label: l.subtotal,
              value: CurrencyFormatter.formatPrice(subtotal),
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenHeight * 0.015),
            _SummaryRow(
              label: l.deliveryFee,
              value: CurrencyFormatter.formatPrice(deliveryFee),
              screenWidth: screenWidth,
            ),
            // The total is read before the button that charges it.
            Padding(
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
              child: const Divider(),
            ),
            _SummaryRow(
              label: l.total,
              value: CurrencyFormatter.formatPrice(total),
              isBold: true,
              valueColor: AppColors.primary,
              screenWidth: screenWidth,
            ),
            SizedBox(height: screenHeight * 0.02),
            SizedBox(
              width: double.infinity,
              height: screenHeight * 0.07,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutScreen(
                        subtotal: subtotal,
                        deliveryFee: deliveryFee,
                        total: total,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.04),
                  ),
                ),
                child: Text(
                  l.proceedToCheckout,
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
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

/// "label ........ value" — one line of the summary.
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final double screenWidth;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.screenWidth,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? screenWidth * 0.045 : screenWidth * 0.04,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? textColor : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? screenWidth * 0.05 : screenWidth * 0.04,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? textColor,
          ),
        ),
      ],
    );
  }
}
