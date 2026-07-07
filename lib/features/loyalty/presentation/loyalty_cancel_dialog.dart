import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/data/models/order.dart';
import '../../orders/providers/order_provider.dart';
import '../data/loyalty_eligibility.dart';
import 'widgets/loyalty_stamp.dart';
import 'widgets/loyalty_stamp_grid.dart';

/// Cancellation confirmation dialog showing the just-cancelled order's stamp
/// being removed from the card. Purely a UI projection — see
/// [LoyaltyCardSheet]'s doc comment: there is no server-side pending-points
/// concept to reverse, so "removed" here just means the client stops
/// projecting that stamp; no backend write happens.
class LoyaltyCancelDialog extends StatefulWidget {
  final int stampIndex;

  const LoyaltyCancelDialog({super.key, required this.stampIndex});

  /// Shows the dialog if [order] was loyalty-eligible and still had a
  /// pending stamp. Returns true if the user tapped "Recommander" (the
  /// caller already navigated home in that case and should not also pop).
  /// Returns false for every other outcome, including a silent skip.
  static Future<bool> maybeShow(
    BuildContext context, {
    required WidgetRef ref,
    required Order order,
  }) async {
    if (!kLoyaltyEligibleOrderTypes.contains(order.type)) return false;

    late final int stampIndex;
    try {
      final count = await ref.read(orderRepositoryProvider).getLoyaltyDeliveredCount();
      stampIndex = count % kLoyaltyTotalSlots;
    } catch (_) {
      return false;
    }

    if (!context.mounted) return false;
    final reordered = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'loyalty_cancel_dialog',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, secondaryAnim) => LoyaltyCancelDialog(stampIndex: stampIndex),
      transitionBuilder: (ctx, anim, secondaryAnim, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
    return reordered ?? false;
  }

  @override
  State<LoyaltyCancelDialog> createState() => _LoyaltyCancelDialogState();
}

class _LoyaltyCancelDialogState extends State<LoyaltyCancelDialog> {
  bool _removed = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _removed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.loyaltyDialogBackdropGradient),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 5, decoration: const BoxDecoration(gradient: AppColors.loyaltyCancelAccentGradient)),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.loyaltyCancelIconGradient,
                      ),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.loyaltyCancelIconColor, size: 26),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.loyaltyCancelTitle,
                      style: const TextStyle(
                        color: AppColors.loyaltyCancelTitleColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.loyaltyCancelMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.loyaltyCancelMiniCardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.loyaltyCancelMiniCardBorder),
                      ),
                      child: LoyaltyStampGrid(
                        earnedCount: widget.stampIndex,
                        totalSlots: kLoyaltyTotalSlots,
                        specialIndex: widget.stampIndex,
                        specialState: _removed ? LoyaltyStampState.removed : LoyaltyStampState.empty,
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.loyaltyCancelNote,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.loyaltyCancelNoteColor, fontSize: 11.5),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.loyaltyCancelButtonGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(true),
                            child: Center(
                              child: Text(
                                l10n.loyaltyCancelPrimaryCta,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.loyaltyCancelSecondaryCta, style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
