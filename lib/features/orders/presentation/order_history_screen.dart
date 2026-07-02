import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/order_provider.dart';
import '../data/models/order.dart';
import 'order_tracking_screen.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.orderHistory,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmptyState(sw, sh);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userOrdersProvider);
            },
            color: AppColors.primary,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(sw * 0.04, sh * 0.01, sw * 0.04, sh * 0.04),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _OrderCard(
                  order: orders[index],
                  sw: sw,
                  sh: sh,
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(sw * 0.1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: sw * 0.15, color: AppColors.error),
                SizedBox(height: sh * 0.02),
                Text(
                  'Failed to load orders',
                  style: TextStyle(
                    fontSize: sw * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: sh * 0.01),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: sw * 0.035,
                  ),
                ),
                SizedBox(height: sh * 0.03),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(userOrdersProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.retry),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: sw * 0.15,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: sh * 0.03),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: sw * 0.055,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: sh * 0.01),
          Text(
            'Your order history will appear here',
            style: TextStyle(
              fontSize: sw * 0.038,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final double sw;
  final double sh;

  const _OrderCard({
    required this.order,
    required this.sw,
    required this.sh,
  });

  @override
  Widget build(BuildContext context) {
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(orderId: order.id),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(sw * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Type icon + ID + Status badge
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(sw * 0.025),
                      decoration: BoxDecoration(
                        color: _getTypeColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(sw * 0.03),
                      ),
                      child: Icon(
                        _getTypeIcon(),
                        color: _getTypeColor(),
                        size: sw * 0.06,
                      ),
                    ),
                    SizedBox(width: sw * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTypeLabel(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: sw * 0.04,
                            ),
                          ),
                          SizedBox(height: sh * 0.003),
                          Text(
                            '#${(order.id.length >= 8 ? order.id.substring(0, 8) : order.id).toUpperCase()}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: sw * 0.03,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),

                Divider(height: sh * 0.025, color: Colors.grey[200]),

                // Details row
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: sw * 0.035, color: Colors.grey[500]),
                    SizedBox(width: sw * 0.015),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: sw * 0.032,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.formatPrice(order.total),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: sw * 0.042,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                // Notes if present
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  SizedBox(height: sh * 0.01),
                  Row(
                    children: [
                      Icon(Icons.notes, size: sw * 0.035, color: Colors.grey[400]),
                      SizedBox(width: sw * 0.015),
                      Expanded(
                        child: Text(
                          order.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: sw * 0.03,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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

  Widget _buildStatusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.025,
        vertical: sw * 0.012,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(sw * 0.05),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        order.getStatusText(),
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: sw * 0.028,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (order.status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.teal;
      case OrderStatus.pickedUp:
        return Colors.indigo;
      case OrderStatus.onTheWay:
        return Colors.lightBlue;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getTypeIcon() {
    switch (order.type) {
      case OrderType.food:
        return Icons.restaurant;
      case OrderType.supermarket:
        return Icons.shopping_cart;
      case OrderType.courier:
        return Icons.local_shipping;
      case OrderType.billPayment:
        return Icons.receipt;
      case OrderType.facture:
        return Icons.electric_bolt_rounded;
    }
  }

  Color _getTypeColor() {
    switch (order.type) {
      case OrderType.food:
        return AppColors.primary;
      case OrderType.supermarket:
        return Colors.green;
      case OrderType.courier:
        return Colors.indigo;
      case OrderType.billPayment:
        return Colors.teal;
      case OrderType.facture:
        return const Color(0xFFFF9500);
    }
  }

  String _getTypeLabel() {
    switch (order.type) {
      case OrderType.food:
        return order.restaurantName.isNotEmpty ? order.restaurantName : 'Food Order';
      case OrderType.supermarket:
        return 'Supermarket Order';
      case OrderType.courier:
        return 'Courier Delivery';
      case OrderType.billPayment:
        return 'Bill Payment';
      case OrderType.facture:
        return 'Paiement de facture';
    }
  }
}
