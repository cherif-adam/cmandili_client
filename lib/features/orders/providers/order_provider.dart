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
