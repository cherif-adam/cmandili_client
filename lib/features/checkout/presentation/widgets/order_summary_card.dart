import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../promo/providers/promo_provider.dart';
import '../../../loyalty/data/loyalty_eligibility.dart';

/// Order summary card that conditionally shows the discount line item.
class OrderSummaryCard extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double estimatedTotal;
  final PromoState promoState;
  final LoyaltyMilestonePreview? loyaltyPreview;
  final double loyaltyDiscountAmount;

  const OrderSummaryCard({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.estimatedTotal,
    required this.promoState,
    this.loyaltyPreview,
    this.loyaltyDiscountAmount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: AppLocalizations.of(context)!.subtotal,
            value: CurrencyFormatter.formatPrice(subtotal),
          ),

          // Discount line — only visible when a promo is applied.
          if (promoState.isApplied) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: AppLocalizations.of(context)!
                  .promoDiscount(promoState.appliedCode),
              value:
                  '− ${CurrencyFormatter.formatPrice(promoState.discountAmount)}',
              valueColor: AppColors.success,
              labelColor: AppColors.success,
            ),
          ],

          const SizedBox(height: 12),
          _SummaryRow(
            label: AppLocalizations.of(context)!.deliveryFee,
            value: CurrencyFormatter.formatPrice(deliveryFee),
          ),

          // Loyalty discount line — only visible on the customer's 5th/10th
          // order. Estimate only; the order actually created may differ if
          // this raced with another order (see predictNextOrderMilestone).
          if (loyaltyPreview != null) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: loyaltyPreview!.type == 'free'
                  ? AppLocalizations.of(context)!.loyaltyFreeDelivery
                  : AppLocalizations.of(context)!.loyaltyHalfDelivery,
              value: '− ${CurrencyFormatter.formatPrice(loyaltyDiscountAmount)}',
              valueColor: AppColors.success,
              labelColor: AppColors.success,
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          _SummaryRow(
            label: AppLocalizations.of(context)!.total,
            value: CurrencyFormatter.formatPrice(estimatedTotal),
            isBold: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final Color? labelColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: labelColor ??
                  (isBold ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ??
                (isBold ? AppColors.textPrimary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
