import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../orders/data/models/order.dart';
import '../../../../orders/presentation/order_tracking_screen.dart';
import 'facture_status_badge.dart';

/// One paid bill: type icon and label, reference, status, date, amount,
/// and "Reçu disponible" once the driver uploaded the receipt. Tap to
/// open its tracking screen.
class FactureHistoryCard extends StatelessWidget {
  final Order order;
  final double sw;
  final double sh;

  const FactureHistoryCard({super.key, required this.order, required this.sw, required this.sh});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final billInfo = _billInfo(l10n, order.billType);

    return Container(
      margin: EdgeInsets.only(bottom: sh * 0.015),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(sw * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: sw * 0.025,
            offset: Offset(0, sh * 0.005),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(sw * 0.04),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
          ),
          child: Padding(
            padding: EdgeInsets.all(sw * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(sw * 0.03),
                      decoration: BoxDecoration(
                        color: billInfo.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(sw * 0.03),
                      ),
                      child: Icon(billInfo.icon, color: billInfo.color, size: sw * 0.07),
                    ),
                    SizedBox(width: sw * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            billInfo.label,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: sw * 0.042),
                          ),
                          if (order.billReference != null) ...[
                            SizedBox(height: sh * 0.003),
                            Text(
                              l10n.billsReference('${order.billReference}'),
                              style: TextStyle(color: Colors.grey[500], fontSize: sw * 0.03, fontFamily: 'monospace'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    FactureStatusBadge(status: order.status, sw: sw),
                  ],
                ),

                Divider(height: sh * 0.025, color: Colors.grey[200]),

                Row(
                  children: [
                    Icon(Icons.calendar_today, size: sw * 0.035, color: Colors.grey[500]),
                    SizedBox(width: sw * 0.015),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: sw * 0.032),
                    ),
                    const Spacer(),
                    if (order.billAmount != null)
                      Text(
                        '${order.billAmount!.toStringAsFixed(3)} TND',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: sw * 0.042,
                          color: billInfo.color,
                        ),
                      ),
                  ],
                ),

                // Receipt available indicator
                if (order.billReceiptUrl != null) ...[
                  SizedBox(height: sh * 0.008),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        l10n.billsReceiptAvailable,
                        style: TextStyle(color: AppColors.success, fontSize: sw * 0.03, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({IconData icon, Color color, String label}) _billInfo(
      AppLocalizations l10n, String? billType) {
    switch (billType) {
      case 'steg':
        return (icon: Icons.bolt_rounded, color: const Color(0xFFF57F17), label: l10n.billsLabelSteg);
      case 'sonede':
        return (icon: Icons.water_drop_rounded, color: const Color(0xFF00695C), label: l10n.billsLabelSonede);
      case 'topnet':
        return (icon: Icons.wifi_rounded, color: const Color(0xFF1565C0), label: l10n.billsLabelTopnet);
      default:
        return (icon: Icons.receipt_long_rounded, color: const Color(0xFF616161), label: l10n.billsLabelOther);
    }
  }
}
