import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/models/order.dart';
import '../../order_labels.dart';
import '../../order_tracking/order_tracking_screen.dart';
import 'reorder_button.dart';

/// One past order in the orders tab. Opens its tracking screen.
///
///   Row: type icon · shop name / #ID ........ _StatusBadge
///   _LoyaltyMilestoneBadge   (when the loyalty discount applied)
///   ──────────────────────────────
///   Row: 📅 date ..................... total
///   note   (when the customer left one)
///   ReorderButton   (delivered food orders)
class OrderHistoryCard extends StatelessWidget {
  final Order order;
  final double sw;
  final double sh;

  const OrderHistoryCard({
    super.key,
    required this.order,
    required this.sw,
    required this.sh,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(order.type);

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
                // Header: type icon + name / ID + status
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(sw * 0.025),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(sw * 0.03),
                      ),
                      child: Icon(
                        _typeIcon(order.type),
                        color: typeColor,
                        size: sw * 0.06,
                      ),
                    ),
                    SizedBox(width: sw * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _typeLabel(AppLocalizations.of(context)!, order),
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
                    _StatusBadge(status: order.status, sw: sw),
                  ],
                ),

                if (order.loyaltyMilestoneType != null) ...[
                  SizedBox(height: sh * 0.01),
                  _LoyaltyMilestoneBadge(
                    milestoneType: order.loyaltyMilestoneType!,
                    sw: sw,
                  ),
                ],

                Divider(height: sh * 0.025, color: Colors.grey[200]),

                // Date and total
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

                // Note, if any
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

                if (order.type == OrderType.food && order.status == OrderStatus.delivered) ...[
                  SizedBox(height: sh * 0.014),
                  ReorderButton(order: order, sw: sw, sh: sh),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(OrderType type) {
    switch (type) {
      case OrderType.food:
        return Icons.restaurant;
      case OrderType.grocery:
      case OrderType.supermarket:
        return Icons.shopping_cart;
      case OrderType.bakery:
        return Icons.bakery_dining_rounded;
      case OrderType.flowers:
        return Icons.local_florist_rounded;
      case OrderType.pets:
        return Icons.pets_rounded;
      case OrderType.gifts:
        return Icons.card_giftcard_rounded;
      case OrderType.electronics:
        return Icons.devices_other_rounded;
      case OrderType.courier:
        return Icons.local_shipping;
      case OrderType.billPayment:
        return Icons.receipt;
      case OrderType.facture:
        return Icons.electric_bolt_rounded;
    }
  }

  static Color _typeColor(OrderType type) {
    switch (type) {
      case OrderType.food:
        return AppColors.primary;
      case OrderType.grocery:
      case OrderType.supermarket:
        return Colors.green;
      case OrderType.bakery:
        return const Color(0xFFD97706);
      case OrderType.flowers:
        return const Color(0xFFEC4899);
      case OrderType.pets:
        return const Color(0xFF8B5CF6);
      case OrderType.gifts:
        return const Color(0xFFF59E0B);
      case OrderType.electronics:
        return const Color(0xFF3B82F6);
      case OrderType.courier:
        return Colors.indigo;
      case OrderType.billPayment:
        return Colors.teal;
      case OrderType.facture:
        return const Color(0xFFFF9500);
    }
  }

  /// For a shop order the shop's NAME says more than its category
  /// ("Digital House" rather than "Electronique"); the category is only the
  /// fallback when the name was not joined.
  ///
  /// Cases are listed one by one rather than grouped under `default`, so the
  /// compiler still flags a forgotten value.
  static String _typeLabel(AppLocalizations l10n, Order order) {
    switch (order.type) {
      case OrderType.food:
      case OrderType.grocery:
      case OrderType.supermarket:
      case OrderType.bakery:
      case OrderType.flowers:
      case OrderType.pets:
      case OrderType.gifts:
      case OrderType.electronics:
        return order.restaurantName.isNotEmpty
            ? order.restaurantName
            : _shopCategoryLabel(l10n, order.type);
      case OrderType.courier:
        return l10n.orderTypeCourier;
      case OrderType.billPayment:
        return l10n.orderTypeFacture;
      case OrderType.facture:
        return l10n.orderTypeFacture;
    }
  }

  static String _shopCategoryLabel(AppLocalizations l10n, OrderType type) {
    switch (type) {
      case OrderType.grocery:
      case OrderType.supermarket:
        return l10n.orderShopSupermarket;
      case OrderType.bakery:
        return l10n.orderShopBakery;
      case OrderType.flowers:
        return l10n.orderShopFlowers;
      case OrderType.pets:
        return l10n.orderShopPets;
      case OrderType.gifts:
        return l10n.orderShopGifts;
      case OrderType.electronics:
        return l10n.orderShopElectronics;
      default:
        return l10n.orderShopRestaurant;
    }
  }
}

/// "En route" / "Livrée" / "Annulée"… in a pill of the status colour.
class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  final double sw;

  const _StatusBadge({required this.status, required this.sw});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.025,
        vertical: sw * 0.012,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(sw * 0.05),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        orderStatusLabel(AppLocalizations.of(context)!, status),
        style: TextStyle(
          color: color,
          fontSize: sw * 0.028,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _statusColor(OrderStatus status) {
    switch (status) {
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
}

/// "🎉 -50% sur la livraison" / "🎉 Livraison gratuite" on orders where the
/// loyalty programme applied a discount.
class _LoyaltyMilestoneBadge extends StatelessWidget {
  final String milestoneType; // 'half' | 'free'
  final double sw;

  const _LoyaltyMilestoneBadge({required this.milestoneType, required this.sw});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = milestoneType == 'free'
        ? l10n.loyaltyBadgeFree
        : l10n.loyaltyBadgeHalf;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.03, vertical: sw * 0.015),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(sw * 0.03),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.green[700],
          fontWeight: FontWeight.bold,
          fontSize: sw * 0.032,
        ),
      ),
    );
  }
}
