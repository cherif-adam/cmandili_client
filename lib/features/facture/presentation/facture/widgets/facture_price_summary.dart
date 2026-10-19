import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../loyalty/data/loyalty_eligibility.dart';
import 'facture_colors.dart';

/// The light-orange box before the submit button:
///   Montant de la facture   (collected in cash)
///   Frais de service        (what the customer pays us)
///   Fidélité discount       (only when the next order earns one)
class FacturePriceSummary extends StatelessWidget {
  /// The raw text of the amount field ("—" is shown until it's a number).
  final String amountText;
  final double serviceFee;
  final LoyaltyMilestonePreview? loyaltyPreview;

  const FacturePriceSummary({
    super.key,
    required this.amountText,
    required this.serviceFee,
    required this.loyaltyPreview,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kFactureOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kFactureOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _PriceRow(
            label: l10n.factureBillAmount,
            value: amountText.isNotEmpty && double.tryParse(amountText) != null
                ? '${double.parse(amountText).toStringAsFixed(3)} TND'
                : '—',
            note: l10n.factureCollectedInCash,
          ),
          const Divider(height: 20),
          _PriceRow(
            label: l10n.factureServiceFee,
            value: '${serviceFee.toStringAsFixed(3)} TND',
            bold: true,
            color: kFactureOrange,
          ),
          if (loyaltyPreview != null) ...[
            const Divider(height: 20),
            _PriceRow(
              label: loyaltyPreview!.type == 'free'
                  ? l10n.loyaltyFreeDelivery
                  : l10n.factureLoyaltyHalf,
              value:
                  '− ${(serviceFee * loyaltyPreview!.discountMultiplier).toStringAsFixed(3)} TND',
              bold: true,
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the summary: label (+ small grey note under it) on the
/// left, value on the right.
class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final bool bold;
  final Color? color;

  const _PriceRow({
    required this.label,
    required this.value,
    this.note,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: bold ? kFactureTextDark : Colors.grey.shade600,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            fontSize: bold ? 16 : 14,
            color: color ?? kFactureTextDark,
          ),
        ),
      ],
    );
  }
}
