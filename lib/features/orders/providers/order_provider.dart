import 'dart:async';

import 'package:flutter/widgets.dart';
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

/// An order the driver has delivered and the customer has not confirmed yet,
/// or null. Drives the "did you receive your order?" reminder on the home
/// screen.
///
/// Re-checked the moment the active order changes (an order leaving "active"
/// is exactly an order being delivered), every 10 s while the app is on
/// screen, and it goes back to null by itself once the customer answers or
/// the server confirms after three minutes.
final receiptPendingOrderProvider = StreamProvider<Order?>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  final controller = StreamController<Order?>();
  var closed = false;

  Future<void> refresh() async {
    final order = await repository.getOrderAwaitingReceipt();
    if (!closed) controller.add(order);
  }

  refresh();
  ref.listen(activeOrderProvider, (_, __) => refresh());
  final timer = Timer.periodic(const Duration(seconds: 10), (_) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      refresh();
    }
  });

  ref.onDispose(() {
    closed = true;
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Whether the driver of [orderId] can still be rated by this customer.
/// Invalidated after a rating is sent.
final canRateDriverProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).canRateDriver(orderId);
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

/// Une commande AVEC ses lignes et le commerce qui la prépare, lue une fois.
///
/// Le flux temps réel de l'écran de suivi ne peut pas les porter : `.stream()`
/// renvoie les lignes brutes de `orders` et ne sait pas faire de jointure
/// PostgREST. D'où cette lecture séparée — le flux garde ce qui bouge, celle-ci
/// apporte ce qui ne bouge plus.
final orderDetailsProvider =
    FutureProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).getOrderWithDetails(orderId);
});
