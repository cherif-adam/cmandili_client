import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order.dart';
import 'order_row_mapper.dart';

/// Realtime streams: the customer's active order, one order, and the
/// delivery / driver rows that carry the driver's position.
class OrderLiveRepository {
  final _supabase = Supabase.instance.client;

  // Stream order updates
  /// Live version of [getActiveOrder]: emits the newest undelivered,
  /// uncancelled order (or null) every time any of the customer's orders
  /// changes, so a restaurant/driver status update shows up immediately.
  Stream<Order?> streamActiveOrder() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          Map<String, dynamic>? newest;
          for (final row in rows) {
            final status = row['status'];
            if (status == 'delivered' || status == 'cancelled') continue;
            if (newest == null ||
                '${row['created_at']}'.compareTo('${newest['created_at']}') > 0) {
              newest = row;
            }
          }
          return newest == null ? null : Order.fromJson(mapOrderFromDb(newest));
        });
  }

  Stream<Order> streamOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((event) {
          if (event.isEmpty) {
            throw Exception('Order not found');
          }
          return Order.fromJson(mapOrderFromDb(event.first));
        });
  }

  /// Live `deliveries` rows of [orderId]: the assigned driver and the GPS
  /// position written on every tick. Rows are passed through untouched.
  Stream<List<Map<String, dynamic>>> streamDeliveryRows(String orderId) {
    return _supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId);
  }

  /// Live `drivers` row of [driverId]: the driver app writes
  /// `current_lat/current_lng` here on every GPS update as well. Rows are
  /// passed through untouched.
  Stream<List<Map<String, dynamic>>> streamDriverRows(String driverId) {
    return _supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId);
  }
}
