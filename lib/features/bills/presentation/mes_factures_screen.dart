import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../orders/data/models/order.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import '../../orders/providers/order_provider.dart';

class MesFacturesScreen extends ConsumerWidget {
  const MesFacturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(billOrdersProvider);
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes factures', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return _buildEmptyState(sw, sh);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(billOrdersProvider),
            color: const Color(0xFFFF9500),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(sw * 0.04, sh * 0.01, sw * 0.04, sh * 0.04),
              itemCount: orders.length,
              itemBuilder: (context, index) => _FactureCard(order: orders[index], sw: sw, sh: sh),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF9500))),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(sw * 0.1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: sw * 0.15, color: AppColors.error),
                SizedBox(height: sh * 0.02),
                const Text('Impossible de charger les factures', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: sh * 0.02),
                ElevatedButton(
                  onPressed: () => ref.invalidate(billOrdersProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(double sw, double sh) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(sw * 0.06),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: sw * 0.15, color: const Color(0xFFFF9500)),
          ),
          SizedBox(height: sh * 0.03),
          Text('Aucune facture payée', style: TextStyle(fontSize: sw * 0.055, fontWeight: FontWeight.bold)),
          SizedBox(height: sh * 0.01),
          Text(
            'Vos paiements de factures apparaîtront ici',
            style: TextStyle(fontSize: sw * 0.038, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _FactureCard extends StatelessWidget {
  final Order order;
  final double sw;
  final double sh;

  const _FactureCard({required this.order, required this.sw, required this.sh});

  @override
  Widget build(BuildContext context) {
    final billInfo = _billInfo(order.billType);

    return Container(
      margin: EdgeInsets.only(bottom: sh * 0.015),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(sw * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                        color: billInfo.color.withOpacity(0.12),
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
                              'Réf: ${order.billReference}',
                              style: TextStyle(color: Colors.grey[500], fontSize: sw * 0.03, fontFamily: 'monospace'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _StatusBadge(status: order.status, sw: sw),
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
                        'Reçu disponible',
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

  ({IconData icon, Color color, String label}) _billInfo(String? billType) {
    switch (billType) {
      case 'steg':
        return (icon: Icons.bolt_rounded, color: const Color(0xFFF57F17), label: 'STEG — Électricité');
      case 'sonede':
        return (icon: Icons.water_drop_rounded, color: const Color(0xFF00695C), label: 'SONEDE — Eau');
      case 'topnet':
        return (icon: Icons.wifi_rounded, color: const Color(0xFF1565C0), label: 'Topnet — Internet');
      default:
        return (icon: Icons.receipt_long_rounded, color: const Color(0xFF616161), label: 'Autre facture');
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  final double sw;

  const _StatusBadge({required this.status, required this.sw});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.pending   => ('En attente', Colors.orange),
      OrderStatus.confirmed => ('Confirmée', Colors.blue),
      OrderStatus.onTheWay  => ('En route', Colors.lightBlue),
      OrderStatus.pickedUp  => ('Espèces collectées', Colors.indigo),
      OrderStatus.delivered => ('Payée', Colors.green),
      OrderStatus.cancelled => ('Annulée', Colors.red),
      _                     => ('En cours', Colors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.025, vertical: sw * 0.012),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(sw * 0.05),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: sw * 0.028, fontWeight: FontWeight.w600),
      ),
    );
  }
}
