import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

/// Bottom of the tracking screen.
///
/// Until pickup: a red "Annuler la commande" button. Mirrors the status
/// list in OrderRepository.cancelOrderByCustomer: cancellable right up to
/// pickup (stopping at 'confirmed' trapped a customer whenever a shop
/// marked an order ready and no driver collected it).
///
/// Once the driver has it: a grey note that it is too late to cancel.
/// Nothing for delivered or cancelled orders.
class CancelOrderSection extends StatelessWidget {
  final OrderStatus status;
  final VoidCallback onCancel;

  const CancelOrderSection({super.key, required this.status, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final canCancel = status == OrderStatus.pending ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.preparing ||
        status == OrderStatus.ready;
    final tooLate = !canCancel &&
        status != OrderStatus.cancelled &&
        status != OrderStatus.delivered &&
        status.index >= OrderStatus.pickedUp.index;

    if (!canCancel && !tooLate) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        if (canCancel)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
              label: Text(
                AppLocalizations.of(context)!.cancelOrderTitle,
                style: const TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.cancelTooLateOnTheWay,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
