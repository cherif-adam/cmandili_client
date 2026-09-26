import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
/// Backs the home screen's "active order" button, the way back into tracking
/// once the customer leaves that screen. It is driven by Supabase realtime so
/// a status change from the restaurant or driver ("Preparing" -> "On the Way")
/// shows up instantly, with a slow poll as a safety net for a dropped socket
/// or a login that happened after this provider was first built.
final activeOrderProvider = StreamProvider<Order?>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  final controller = StreamController<Order?>();
  StreamSubscription<Order?>? realtime;
  Timer? timer;

  void emit(Order? order) {
    if (!controller.isClosed) controller.add(order);
  }

  // Realtime needs a signed-in user; retried from the poll until it attaches.
  void subscribe() {
    if (realtime != null || Supabase.instance.client.auth.currentUser == null) {
      return;
    }
    realtime = repository.streamActiveOrder().listen(
      emit,
      onError: (Object e) {
        debugPrint('activeOrderProvider: realtime failed $e');
        realtime?.cancel();
        realtime = null; // re-attached on the next poll
      },
    );
  }

  // A failed poll is ignored rather than surfaced: an error state would hide
  // the button, and the last known order is still the best answer.
  Future<void> poll() async {
    subscribe();
    try {
      emit(await repository.getActiveOrder());
    } catch (e) {
      debugPrint('activeOrderProvider: poll failed $e');
    }
  }

  poll();
  timer = Timer.periodic(const Duration(seconds: 20), (_) => poll());

  ref.onDispose(() {
    timer?.cancel();
    realtime?.cancel();
    controller.close();
  });
  return controller.stream;
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
