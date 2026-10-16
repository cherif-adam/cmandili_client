import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/services/route_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/models/cart_item.dart';
import '../../data/models/order.dart';
import 'cancel_order_section.dart';
import 'colis_receipt_card.dart';
import 'driver_info_card.dart';
import 'loyalty_applied_banner.dart';
import 'order_details_section.dart';
import 'order_timeline.dart';
import 'receipt_confirmation_card.dart';
import 'route_summary_card.dart';
import 'tracking_status_header.dart';

/// The white panel over the map on the tracking screen (drag it up for
/// more), top to bottom:
///
///   TrackingStatusHeader     "En route", estimated time
///   ColisReceiptCard         parcels: code, proofs, report
///   ReceiptConfirmationCard  once delivered: "did you receive it?"
///   RouteSummaryCard         live ETA, distance, streets
///   LoyaltyAppliedBanner
///   parcel receipt button / "recipient accepted"
///   OrderTimeline
///   DriverInfoCard           while the driver has the order
///   OrderDetailsSection      what was ordered, total, payment
///   CancelOrderSection
class TrackingDetailsSheet extends StatelessWidget {
  final Order order;

  /// The live route, while the driver is moving on the map; else null.
  final AppRoute? route;
  final String shopName;
  final List<CartItem> items;
  final bool hasPreparationStep;
  final VoidCallback onCancel;
  final VoidCallback onConfirmRecipientReceipt;

  /// Called when the receipt question (and driver rating) is done.
  final VoidCallback onReceiptFlowFinished;

  const TrackingDetailsSheet({
    super.key,
    required this.order,
    required this.route,
    required this.shopName,
    required this.items,
    required this.hasPreparationStep,
    required this.onCancel,
    required this.onConfirmRecipientReceipt,
    required this.onReceiptFlowFinished,
  });

  @override
  Widget build(BuildContext context) {
    final isCourier = order.type == OrderType.courier;
    final isFacture = order.type == OrderType.facture;
    final driverOnTheWay = (order.status == OrderStatus.onTheWay ||
            order.status == OrderStatus.pickedUp) &&
        order.driverName != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              const _DragHandle(),
              const SizedBox(height: 20),
              TrackingStatusHeader(order: order, liveEta: route?.etaLabel),

              // Parcels: delivery code, then proofs once delivered, then a
              // report window of 24 h. Renders nothing without a receipt.
              if (isCourier) ...[
                const SizedBox(height: 16),
                ColisReceiptCard(orderId: order.id, deliveredAt: order.deliveredAt),
              ],

              // The driver says it is delivered: ask the customer.
              if (order.status == OrderStatus.delivered) ...[
                const SizedBox(height: 16),
                ReceiptConfirmationCard(
                  order: order,
                  onFlowFinished: onReceiptFlowFinished,
                ),
              ],

              if (route != null) ...[
                const SizedBox(height: 16),
                RouteSummaryCard(route: route!),
              ],

              if (order.status == OrderStatus.delivered &&
                  order.loyaltyMilestoneType != null) ...[
                const SizedBox(height: 16),
                LoyaltyAppliedBanner(milestoneType: order.loyaltyMilestoneType!),
              ],

              const SizedBox(height: 24),

              if (isCourier &&
                  order.status == OrderStatus.onTheWay &&
                  !order.isRecipientAccepted)
                _ConfirmReceiptButton(onPressed: onConfirmRecipientReceipt),

              if (order.isRecipientAccepted) const _RecipientAcceptedNote(),

              OrderTimeline(
                status: order.status,
                isCourier: isCourier,
                isFacture: isFacture,
                hasPreparationStep: hasPreparationStep,
              ),

              const SizedBox(height: 24),

              if (driverOnTheWay) ...[
                DriverInfoCard(driverName: order.driverName!, driverPhone: order.driverPhone),
                const SizedBox(height: 24),
              ],

              OrderDetailsSection(order: order, shopName: shopName, items: items),
              CancelOrderSection(status: order.status, onCancel: onCancel),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// The small grey bar at the top of the panel.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Parcels on the way: amber "Confirmer la réception".
class _ConfirmReceiptButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ConfirmReceiptButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(AppLocalizations.of(context)!.confirmReceipt),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Green "the recipient accepted the parcel".
class _RecipientAcceptedNote extends StatelessWidget {
  const _RecipientAcceptedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.recipientAccepted,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
