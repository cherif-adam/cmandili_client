import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../order_labels.dart';

/// Top of the tracking panel: the status in big letters ("En préparation")
/// and the estimated delivery time under it.
class TrackingStatusHeader extends StatelessWidget {
  final Order order;

  /// The live route's ETA once a driver is moving; null before that.
  ///
  /// The stored estimate is a single restaurant→customer duration frozen at
  /// checkout; the live route runs driver→customer from where they actually
  /// are, so it answers the question the customer is asking.
  final String? liveEta;

  const TrackingStatusHeader({super.key, required this.order, this.liveEta});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          orderStatusLabel(l, order.status),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (liveEta != null)
          Text(
            l.estimatedDeliveryAt(liveEta!),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          )
        else if (order.estimatedDeliveryTime != null)
          Text(
            l.estimatedDeliveryAt(_formatTime(l, order.estimatedDeliveryTime!)),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
      ],
    );
  }

  static String _formatTime(AppLocalizations l, DateTime time) {
    final difference = time.difference(DateTime.now());
    if (difference.inMinutes < 60) return l.etaMinutes('${difference.inMinutes}');
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
