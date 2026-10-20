import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../orders/data/models/order.dart';
import '../../../../orders/presentation/order_tracking/order_tracking_screen.dart';
import '../../../../orders/providers/order_provider.dart';

/// The green pill above the menu bar that leads back into order tracking:
/// "Commande en cours", or "Avez-vous reçu votre commande ?" once delivered.
/// Shows on every tab; nothing at all when there is no order to follow.
///
/// Returns a [Positioned], so it must be a direct child of a [Stack].
class ActiveOrderPill extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const ActiveOrderPill({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sw = screenWidth;
    final sh = screenHeight;
    // activeOrderProvider re-polls, so an order placed during this session
    // appears here and a delivered/cancelled one disappears without a restart.
    final activeOrder = ref.watch(activeOrderProvider).valueOrNull;
    // A delivered order waiting for "did you receive it?" is no longer
    // active, so it would have no way back into the tracking screen where
    // the question is asked. It takes the pill, and takes it first: the
    // question closes by itself after three minutes.
    final awaitingReceipt = ref.watch(receiptPendingOrderProvider).valueOrNull;
    final pillOrder = awaitingReceipt ?? activeOrder;
    if (pillOrder == null) return const SizedBox.shrink();
    final isReceipt = awaitingReceipt != null;
    final pillColor = isReceipt ? AppColors.success : AppColors.primary;
    final l = AppLocalizations.of(context)!;

    return Positioned(
      left: sw * 0.06,
      // Leaves room for the AI chat FAB, which sits at the same height on the
      // right edge (16 margin + 56 FAB + 8 gap).
      right: 80,
      bottom: sh * 0.03 + sh * 0.085 + sh * 0.015,
      child: Material(
        color: pillColor,
        elevation: 6,
        shadowColor: pillColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(sw * 0.05),
        child: InkWell(
          borderRadius: BorderRadius.circular(sw * 0.05),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(orderId: pillOrder.id),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.035, vertical: sh * 0.012),
            child: Row(
              children: [
                Icon(
                  isReceipt ? Icons.inventory_2_rounded : Icons.delivery_dining,
                  color: Colors.white,
                ),
                SizedBox(width: sw * 0.025),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isReceipt
                            ? (pillOrder.type == OrderType.courier
                                ? l.receiptQuestionParcel
                                : l.receiptQuestion)
                            : l.activeOrder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: sw * 0.037,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isReceipt
                            ? l.receiptTapToConfirm
                            : pillOrder.getStatusText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: sw * 0.032,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
