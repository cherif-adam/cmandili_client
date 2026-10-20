import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order.dart';

/// Changes an existing order: status, cancellation, receipt confirmation.
class OrderStatusRepository {
  final _supabase = Supabase.instance.client;

  // Update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _supabase.from('orders').update({
        'status': status.toString().split('.').last,
      }).eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  /// Sets order status to 'confirmed' after successful payment.
  Future<bool> confirmOrder(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': 'confirmed'})
          .eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error confirming order: $e');
      return false;
    }
  }

  /// Cancel an order that failed payment (sets status to 'cancelled').
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  /// Customer-initiated cancellation. Only succeeds if the order belongs to the
  /// current user AND the goods have not been picked up yet.
  ///
  /// 'preparing' and 'ready' are cancellable too: an order the shop marked
  /// ready but that no driver ever collected used to trap the customer — the
  /// button refused it, and the only ways out were the partner app, the driver
  /// app or an admin. The cut-off is pickup, not readiness, because that is
  /// the point where a driver is actually carrying the food.
  ///
  /// Returns true if a row was actually updated (i.e. cancellation was applied).
  Future<bool> cancelOrderByCustomer(String orderId, String reason) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase
          .from('orders')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason,
            'cancelled_by': 'customer',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'confirmed', 'preparing', 'ready'])
          .select('id');

      return (result as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error cancelling order by customer: $e');
      return false;
    }
  }

  // ── Receipt confirmation ──────────────────────────────────────────────────

  /// Records the customer's answer to "did you receive your order?".
  ///
  /// Goes through the confirm_order_receipt() database function rather than
  /// an UPDATE: the orders column guard only lets a customer change a short
  /// whitelist of columns, and the function also files the support ticket
  /// when the answer is no. Returns the stored state ('confirmed' /
  /// 'not_received'), or null if it could not be saved.
  Future<String?> confirmReceipt(String orderId, {required bool received}) async {
    try {
      final result = await _supabase.rpc('confirm_order_receipt', params: {
        'p_order_id': orderId,
        'p_received': received,
      });
      return result as String?;
    } catch (e) {
      debugPrint('confirmReceipt failed: $e');
      return null;
    }
  }
}
