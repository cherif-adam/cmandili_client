import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_map.dart';
import '../../data/models/order.dart';
import '../../data/order_live_repository.dart';
import '../../providers/order_provider.dart';

/// One controller per tracking screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces.
final orderTrackingControllerProvider = NotifierProvider.autoDispose
    .family<OrderTrackingController, OrderTrackingState, Object>(
        OrderTrackingController.new);

/// The driver's live position, as the marker shows it.
@immutable
class OrderTrackingState {
  const OrderTrackingState({this.driverLat, this.driverLng, this.driverBearing});

  final double? driverLat;
  final double? driverLng;

  // Heading in degrees, derived from the last two valid GPS fixes — lets the
  // driver marker visibly point the direction they're moving. Null until we
  // have two fixes to compare (the very first position has no "from").
  final double? driverBearing;

  /// Whether a real driver position is known (see [isValidCoord]).
  bool get hasValidPosition => isValidCoord(driverLat, driverLng);

  /// A delivery row is created with placeholder (0,0) coordinates the moment a
  /// driver accepts, before the first GPS tick lands. Treat that (and any
  /// null) as "no live location yet" so we never drop a marker in the ocean.
  static bool isValidCoord(double? lat, double? lng) =>
      lat != null && lng != null && !(lat == 0 && lng == 0);
}

/// The live parts of the tracking screen that are not the map: the driver's
/// position (two realtime sources) and the cancel / confirm actions.
class OrderTrackingController
    extends AutoDisposeFamilyNotifier<OrderTrackingState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  StreamSubscription? _deliverySubscription;
  StreamSubscription? _driverSubscription;
  String? _driverId;
  late OrderLiveRepository _repository;

  /// Set once the screen has closed: no event is applied after that.
  bool _stopped = false;

  @override
  OrderTrackingState build(Object screenKey) {
    // Safety net: the screen already stops both sources in its dispose().
    ref.onDispose(stopFollowing);
    return const OrderTrackingState();
  }

  /// The newest position, for code that runs after a build (post-frame
  /// camera fit, recenter tap) and must see the latest GPS tick, as the
  /// screen's own fields used to give it.
  OrderTrackingState get latest => state;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Starts following the driver of [orderId]. Call once, from the screen's
  /// initState; [stopFollowing] ends it.
  void followDriver(String orderId) {
    _repository = ref.read(orderLiveRepositoryProvider);
    _subscribeToDelivery(orderId);
  }

  /// Cancels both realtime subscriptions. Called by the screen's dispose(),
  /// and again (harmlessly) when this controller is disposed.
  void stopFollowing() {
    _stopped = true;
    _deliverySubscription?.cancel();
    _deliverySubscription = null;
    _driverSubscription?.cancel();
    _driverSubscription = null;
  }

  void _subscribeToDelivery(String orderId) {
    _deliverySubscription =
        _repository.streamDeliveryRows(orderId).listen((rows) {
      if (_stopped || rows.isEmpty) return;
      final row = rows.first;

      // Latch onto the assigned driver so we can also watch the `drivers`
      // table directly — it's updated on every GPS tick too and acts as a
      // fallback if the delivery row lags behind.
      final driverId = row['driver_id'] as String?;
      if (driverId != null && driverId != _driverId) {
        _driverId = driverId;
        _subscribeToDriver(driverId);
      }

      final newLat = (row['current_lat'] as num?)?.toDouble();
      final newLng = (row['current_lng'] as num?)?.toDouble();
      _updateDriverPosition(newLat, newLng);
    });
  }

  /// Second live source: the `drivers` row for the assigned driver. The driver
  /// app writes `current_lat/current_lng` here on every GPS update as well, so
  /// subscribing to it keeps the marker moving even if the delivery row's
  /// coordinates haven't been written yet.
  void _subscribeToDriver(String driverId) {
    _driverSubscription?.cancel();
    _driverSubscription = _repository.streamDriverRows(driverId).listen((rows) {
      if (_stopped || rows.isEmpty) return;
      final newLat = (rows.first['current_lat'] as num?)?.toDouble();
      final newLng = (rows.first['current_lng'] as num?)?.toDouble();
      _updateDriverPosition(newLat, newLng);
    });
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Whether the cancellation went through (false: too late, the shop is
  /// already preparing).
  Future<bool> cancelByCustomer(String orderId, String reason) =>
      ref.read(orderStatusRepositoryProvider).cancelOrderByCustomer(orderId, reason);

  /// The customer confirms the recipient got the order.
  Future<void> confirmReceipt(String orderId) => ref
      .read(orderStatusRepositoryProvider)
      .updateOrderStatus(orderId, OrderStatus.delivered);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Apply a new driver location to the marker, ignoring the (0,0) placeholder
  /// that a freshly-created delivery row carries. The camera is intentionally
  /// left alone here — recentering on every GPS tick (roughly once a second)
  /// used to yank the map out from under the user while they browsed the
  /// bottom sheet. Instead the screen fits the camera to driver+destination
  /// once, the first time a valid location appears.
  void _updateDriverPosition(double? lat, double? lng) {
    if (!OrderTrackingState.isValidCoord(lat, lng)) return;
    final newLat = lat!;
    final newLng = lng!;
    // Only recompute heading when the driver actually moved a meaningful
    // amount — GPS jitter on a stationary/slow driver would otherwise spin
    // the marker to a near-random bearing between two nearly-identical
    // points. ~5m in degrees at typical latitudes; cheap to over-approximate
    // since this only gates whether we bother updating the display heading.
    const minMoveDeg = 0.00005;
    final prevLat = state.driverLat;
    final prevLng = state.driverLng;
    double? newBearing = state.driverBearing;
    if (prevLat != null &&
        prevLng != null &&
        ((newLat - prevLat).abs() > minMoveDeg || (newLng - prevLng).abs() > minMoveDeg)) {
      newBearing = bearingBetween((lat: prevLat, lng: prevLng), (lat: newLat, lng: newLng));
    }
    state = OrderTrackingState(
      driverLat: newLat,
      driverLng: newLng,
      driverBearing: newBearing,
    );
  }
}
