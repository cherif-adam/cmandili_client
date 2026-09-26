import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/order_repository.dart';
import '../data/models/order.dart';

final orderRepositoryProvider = Provider((ref) => OrderRepository());

// Stream provider for tracking a specific order
final orderStreamProvider = StreamProvider.family<Order, String>((ref, orderId) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.streamOrder(orderId);
});

// Future provider for fetching user orders history
final userOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getUserOrders();
});

/// The customer's current in-flight order, or null when nothing is running.
///
/// Backs the home screen's "active order" banner, which is the only way back
/// into tracking once the customer leaves that screen — a FutureProvider
/// resolved once at startup left the banner stuck on stale data (or absent
/// entirely for an order placed later in the session), stranding the customer
/// with no route back to their own delivery. Polling keeps it honest without
/// needing a socket: orders are low-frequency, and the tracking screen itself
/// still uses [orderStreamProvider] for live updates.
final activeOrderProvider = StreamProvider<Order?>((ref) async* {
  final repository = ref.watch(orderRepositoryProvider);

  Order? pick(List<Order> orders) {
    for (final o in orders) {
      if (o.status != OrderStatus.delivered &&
          o.status != OrderStatus.cancelled) {
        return o;
      }
    }
    return null;
  }

  yield pick(await repository.getUserOrders());
  await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
    yield pick(await repository.getUserOrders());
  }
});

// Future provider for fetching facture (bill payment) orders only
final billOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getBillOrders();
});

// Future provider for the customer's lifetime loyalty delivered-order count
final loyaltyProgressProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getLoyaltyDeliveredCount();
});
