import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../promo/presentation/promo_error_text.dart';
import '../../../promo/providers/promo_provider.dart';

/// Promo code input with Apply / Remove button and an inline feedback badge.
///
/// Layout:
///   ┌─────────────────────────────┬──────────────┐
///   │  🏷  Enter promo code…      │  [Apply]     │
///   ├─────────────────────────────┴──────────────┤
///   │  ✓ −5.000 DT de réduction appliquée!       │  ← success badge
///   │  ✗ Ce code a expiré                        │  ← error badge
///   └────────────────────────────────────────────┘
class PromoCodeField extends StatelessWidget {
  final TextEditingController controller;
  final PromoState promoState;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  const PromoCodeField({
    super.key,
    required this.controller,
    required this.promoState,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = promoState.status == PromoStatus.loading;
    final isApplied = promoState.isApplied;
    final isError = promoState.status == PromoStatus.error;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApplied
              ? AppColors.success
              : isError
                  ? AppColors.error
                  : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Input row ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isApplied,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: isApplied
                        ? AppColors.success
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context)!.promoCodePlaceholder,
                    prefixIcon: Icon(
                      Icons.discount_outlined,
                      color: isApplied ? AppColors.success : AppColors.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!isApplied) onApply();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: isApplied
                    // ── Remove button ──────────────────────────────────
                    ? TextButton(
                        onPressed: onRemove,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.removePromoCode,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      )
                    // ── Apply button ───────────────────────────────────
                    : ElevatedButton(
                        onPressed: isLoading ? null : onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                AppLocalizations.of(context)!.applyPromoCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
              ),
            ],
          ),

          // ── Feedback badge ─────────────────────────────────────────────
          if (isApplied)
            _PromoBadge(
              isSuccess: true,
              // « − 3.500 DT sur 12.000 DT éligibles » quand une partie du
              // panier est déjà en promotion : sans cette précision, un client
              // dont la moitié des articles sont remisés lit une réduction
              // plus faible qu'annoncée et croit à une erreur. Quand tout est
              // éligible, la phrase habituelle suffit.
              message: promoState.showsEligibleBreakdown
                  ? AppLocalizations.of(context)!.promoOnEligible(
                      CurrencyFormatter.formatPrice(promoState.discountAmount),
                      CurrencyFormatter.formatPrice(
                          promoState.response!.eligibleSubtotal!),
                    )
                  : '− ${CurrencyFormatter.formatPrice(promoState.discountAmount)} '
                      '${AppLocalizations.of(context)!.promoApplied}',
            )
          else if (isError)
            _PromoBadge(
              isSuccess: false,
              message: promoErrorText(
                  AppLocalizations.of(context)!, promoState.response!),
            ),
        ],
      ),
    );
  }
}

class _PromoBadge extends StatelessWidget {
  final bool isSuccess;
  final String message;

  const _PromoBadge({required this.isSuccess, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
