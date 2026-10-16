import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cart/data/models/cart_item.dart';
import '../../data/models/order.dart';
import '../order_labels.dart';

/// What was ordered, on the tracking screen:
///
///   title ("Détails de la commande" / "du colis" / "de la facture")
///   bill: type, reference, amount, phone, bill photo, payment receipt
///   parcel: recipient, phone, item
///   shop order: shop name, "2x Pizza …… 25,00 DT" lines
///   ──────────
///   Total ................ 36,00 DT
///   💳 payment method
class OrderDetailsSection extends StatelessWidget {
  final Order order;

  /// The shop's name, from the order or its separately loaded details.
  final String shopName;
  final List<CartItem> items;

  const OrderDetailsSection({
    super.key,
    required this.order,
    required this.shopName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isCourier = order.type == OrderType.courier;
    final isFacture = order.type == OrderType.facture;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFacture
              ? l.billDetailsTitle
              : isCourier
                  ? l.packageDetails
                  : l.orderDetailsTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        if (isFacture) ...[
          _DetailRow(label: l.billTypeField, value: _billTypeLabel(l, order.billType)),
          _DetailRow(label: l.billReferenceField, value: order.billReference ?? 'N/A'),
          _DetailRow(
              label: l.billAmountField,
              value: order.billAmount != null
                  ? '${order.billAmount!.toStringAsFixed(3)} TND'
                  : 'N/A'),
          if (order.senderPhone != null)
            _DetailRow(label: l.phone, value: order.senderPhone!),
          const SizedBox(height: 16),
          // Bill photo, if the customer uploaded one
          if (order.billPhotoUrl != null) ...[
            Text(l.billPhotoLabel,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            _ProofPhoto(url: order.billPhotoUrl!),
            const SizedBox(height: 16),
          ],
          // Receipt photo, if the driver uploaded one
          if (order.billReceiptUrl != null) ...[
            Text(l.paymentReceiptLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.success)),
            const SizedBox(height: 8),
            _ProofPhoto(url: order.billReceiptUrl!),
            const SizedBox(height: 16),
          ],
        ] else if (isCourier) ...[
          _DetailRow(label: l.recipient, value: order.recipientName ?? 'N/A'),
          _DetailRow(label: l.phone, value: order.recipientPhone ?? 'N/A'),
          _DetailRow(label: l.item, value: order.packageDescription ?? l.packageFallback),
          const SizedBox(height: 16),
        ] else ...[
          if (shopName.isNotEmpty) ...[
            Text(
              shopName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
          ],
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${item.quantity}x ${item.name}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  Text(CurrencyFormatter.formatPrice(item.totalPrice),
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],

        const Divider(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l.total,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              CurrencyFormatter.formatPrice(order.total),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            const Icon(Icons.payments_outlined, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(paymentMethodLabel(l, order.paymentMethod),
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  static String _billTypeLabel(AppLocalizations l, String? billType) {
    switch (billType) {
      case 'steg':
        return l.billTypeElectricity;
      case 'sonede':
        return l.billTypeWater;
      case 'topnet':
        return l.billTypeInternet;
      case 'autre':
        return l.cancelReasonOther;
      default:
        // A type added in the database but not here yet: its key beats
        // nothing.
        return billType ?? 'N/A';
    }
  }
}

/// "Label ...... value" — one line of the bill / parcel details.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// A 140 px photo (bill or payment receipt); tap to see it full screen.
class _ProofPhoto extends StatelessWidget {
  final String url;

  const _ProofPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  static void _showFullScreenImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
