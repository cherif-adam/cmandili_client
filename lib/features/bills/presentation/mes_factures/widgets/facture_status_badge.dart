import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../orders/data/models/order.dart';

/// The bill order's status in a pill of the status colour.
class FactureStatusBadge extends StatelessWidget {
  final OrderStatus status;
  final double sw;

  const FactureStatusBadge({super.key, required this.status, required this.sw});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (status) {
      OrderStatus.pending   => (l10n.orderStatusPending, Colors.orange),
      OrderStatus.confirmed => (l10n.orderStatusConfirmed, Colors.blue),
      OrderStatus.onTheWay  => (l10n.orderStatusOnTheWay, Colors.lightBlue),
      OrderStatus.pickedUp  => (l10n.timelineCashCollected, Colors.indigo),
      OrderStatus.delivered => (l10n.billStatusPaid, Colors.green),
      OrderStatus.cancelled => (l10n.orderStatusCancelled, Colors.red),
      _                     => (l10n.billStatusInProgress, Colors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.025, vertical: sw * 0.012),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(sw * 0.05),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: sw * 0.028, fontWeight: FontWeight.w600),
      ),
    );
  }
}
