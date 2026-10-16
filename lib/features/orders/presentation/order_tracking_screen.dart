import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/route_service.dart';
import '../../../core/widgets/app_map.dart';
import '../data/models/order.dart';
import '../../../core/providers/vendor_provider.dart';
import '../providers/order_provider.dart';
import '../../loyalty/presentation/loyalty_card_sheet.dart';
import '../../loyalty/presentation/loyalty_cancel_dialog.dart';
import '../../rating/presentation/rating_prompt_sheet.dart';
import 'widgets/cancel_order_dialog.dart';
import 'widgets/receipt_confirmation_card.dart';
import 'widgets/tracking_details_sheet.dart';

/// Following an order, top to bottom:
///
///   live map (driver, pickup, delivery, route) — or a big icon before
///   a driver shares a position; ← back, ◎ recenter
///   TrackingDetailsSheet — status, cards, timeline, driver, details,
///   cancel
///
/// This class keeps the live parts: the driver's position (two realtime
/// sources), the route and camera, and the cancel / confirm actions.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  /// Set only by the screens that just created this order (checkout,
  /// courier, facture) — gates the one-time loyalty sheet so it never
  /// reappears when an old order is reopened from history/home.
  final bool justPlaced;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.justPlaced = false,
  });

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final AppMapController _mapController = AppMapController();
  double? _driverLat;
  double? _driverLng;
  // Heading in degrees, derived from the last two valid GPS fixes — lets the
  // driver marker visibly point the direction they're moving. Null until we
  // have two fixes to compare (the very first position has no "from").
  double? _driverBearing;
  StreamSubscription? _deliverySubscription;
  StreamSubscription? _driverSubscription;
  String? _driverId;
  /// The street-following route currently drawn on the map, plus its ETA,
  /// distance and the list of road names it runs along.
  AppRoute? _route;
  List<({double lat, double lng})>? get _routePolyline => _route?.points;
  // Facture orders switch destination mid-delivery (customer's address while
  // onTheWay, then the office once pickedUp) — a route drawn to the old
  // destination is wrong outright, not just stale, so any destination change
  // forces a re-fetch regardless of where the driver is.
  ({double lat, double lng})? _lastRouteFetchDestination;
  bool _routeFetchInFlight = false;
  /// When the last Directions call went out, used to rate-limit re-routing.
  DateTime? _lastRouteFetchAt;
  /// Destination the camera is currently framed on; null until the first
  /// fit. Compared against the live destination so the map reframes when the
  /// driver collects the order and turns towards the customer.
  ({double lat, double lng})? _fittedForLeg;
  bool _loyaltySheetScheduled = false;
  bool _ratingPromptScheduled = false;
  final _supabase = Supabase.instance.client;

  /// A delivery row is created with placeholder (0,0) coordinates the moment a
  /// driver accepts, before the first GPS tick lands. Treat that (and any
  /// null) as "no live location yet" so we never drop a marker in the ocean.
  static bool _isValidCoord(double? lat, double? lng) =>
      lat != null && lng != null && !(lat == 0 && lng == 0);

  @override
  void initState() {
    super.initState();
    _subscribeToDelivery();
  }

  void _maybeScheduleLoyaltySheet(Order order) {
    if (!widget.justPlaced || _loyaltySheetScheduled) return;
    _loyaltySheetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LoyaltyCardSheet.maybeShow(context, ref: ref, order: order);
    });
  }

  // Gated on order.status itself (not just "first build", unlike the
  // loyalty sheet's justPlaced gate) because a customer can be watching
  // this exact screen live as the order transitions into 'delivered' --
  // latching the one-shot flag before that transition happens would mean
  // the prompt never fires for anyone actually watching delivery complete.
  // Fine-grained eligibility (food order, not already rated) still lives in
  // RatingPromptSheet.maybeShow itself.
  void _maybeScheduleRatingPrompt(Order order) {
    if (order.status != OrderStatus.delivered || _ratingPromptScheduled) return;
    // First things first: the customer is being asked whether the order
    // arrived at all (ReceiptConfirmationCard), and may be rating the driver
    // right after. Rating the shop waits for that, and is not latched here
    // so it still fires once they have answered.
    if (order.awaitsReceiptConfirmation || ReceiptConfirmationCard.flowBusy) {
      return;
    }
    _ratingPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RatingPromptSheet.maybeShow(context, ref: ref, order: order);
    });
  }

  void _subscribeToDelivery() {
    _deliverySubscription = _supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('order_id', widget.orderId)
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;
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
    _driverSubscription = _supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;
          final newLat = (rows.first['current_lat'] as num?)?.toDouble();
          final newLng = (rows.first['current_lng'] as num?)?.toDouble();
          _updateDriverPosition(newLat, newLng);
        });
  }

  /// Apply a new driver location to the marker, ignoring the (0,0) placeholder
  /// that a freshly-created delivery row carries. The camera is intentionally
  /// left alone here — recentering on every GPS tick (roughly once a second)
  /// used to yank the map out from under the user while they browsed the
  /// bottom sheet. Instead we fit the camera to driver+destination once, in
  /// [_buildTracking], the first time a valid location appears.
  void _updateDriverPosition(double? lat, double? lng) {
    if (!_isValidCoord(lat, lng)) return;
    final newLat = lat!;
    final newLng = lng!;
    // Only recompute heading when the driver actually moved a meaningful
    // amount — GPS jitter on a stationary/slow driver would otherwise spin
    // the marker to a near-random bearing between two nearly-identical
    // points. ~5m in degrees at typical latitudes; cheap to over-approximate
    // since this only gates whether we bother updating the display heading.
    const minMoveDeg = 0.00005;
    final prevLat = _driverLat;
    final prevLng = _driverLng;
    double? newBearing = _driverBearing;
    if (prevLat != null &&
        prevLng != null &&
        ((newLat - prevLat).abs() > minMoveDeg || (newLng - prevLng).abs() > minMoveDeg)) {
      newBearing = bearingBetween((lat: prevLat, lng: prevLng), (lat: newLat, lng: newLng));
    }
    setState(() {
      _driverLat = newLat;
      _driverLng = newLng;
      _driverBearing = newBearing;
    });
  }

  /// Fetch the street-following route from the driver to [destination] and
  /// draw it. Delegates to [RouteService], which stitches the per-step
  /// geometry (so the line follows the actual roadway rather than the
  /// simplified overview) and reports the road names along the way.
  Future<void> _fetchRoute({
    required ({double lat, double lng}) origin,
    required ({double lat, double lng}) destination,
  }) async {
    if (_routeFetchInFlight) return;
    _routeFetchInFlight = true;
    _lastRouteFetchDestination = destination;
    _lastRouteFetchAt = DateTime.now();

    try {
      final route = await RouteService.fetchDrivingRoute(
        origin: origin,
        destination: destination,
      );
      if (route == null || !mounted) return;
      setState(() => _route = route);
    } finally {
      _routeFetchInFlight = false;
    }
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    _driverSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _showCancelDialog(Order order) async {
    final confirmed =
        await showCancelOrderDialog(context, hasDriver: order.driverId != null);

    if (confirmed == null || !mounted) return;

    final success = await ref
        .read(orderRepositoryProvider)
        .cancelOrderByCustomer(widget.orderId, confirmed);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderCancelledOk),
          backgroundColor: Colors.red,
        ),
      );
      final reordered = await LoyaltyCancelDialog.maybeShow(context, ref: ref, order: order);
      if (!mounted) return;
      if (reordered) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cancelTooLatePreparing),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmReceipt() async {
    await ref
        .read(orderRepositoryProvider)
        .updateOrderStatus(widget.orderId, OrderStatus.delivered);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderMarkedDelivered),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderStreamProvider(widget.orderId));

    return orderAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(AppLocalizations.of(context)!.errorLoadingOrder)),
      ),
      data: (order) {
        _maybeScheduleLoyaltySheet(order);
        _maybeScheduleRatingPrompt(order);
        return _buildTracking(order);
      },
    );
  }

  Widget _buildTracking(Order order) {
    final isCourier = order.type == OrderType.courier;
    final isFacture = order.type == OrderType.facture;

    // Le flux temps réel porte ce qui bouge — statut, livreur, position — mais
    // PAS les lignes de la commande : `.stream()` renvoie les lignes brutes de
    // `orders` et ne sait pas faire de jointure PostgREST. Le « Récapitulatif »
    // était donc vide pour TOUTES les catégories, restaurants compris. Cette
    // lecture séparée apporte ce qui ne bouge plus une fois la commande créée.
    final details = ref.watch(orderDetailsProvider(widget.orderId)).valueOrNull;
    final shopCategory = order.shopCategory ?? details?.shopCategory;
    final shopName = order.restaurantName.isNotEmpty
        ? order.restaurantName
        : (details?.restaurantName ?? '');
    final items = order.items.isNotEmpty ? order.items : (details?.items ?? const []);
    // Show the live map as soon as we have a real driver location, for any
    // status where a driver could be en route. This no longer requires the
    // order status to be exactly onTheWay/pickedUp — the moment a driver is
    // assigned and sending GPS, the customer can watch them move.
    final showMap = _isValidCoord(_driverLat, _driverLng) &&
        order.status != OrderStatus.pending &&
        order.status != OrderStatus.cancelled &&
        order.status != OrderStatus.delivered;

    // Which leg is the driver actually on?
    //
    // Until the order is collected the driver is travelling to the PICKUP
    // point, not to the customer. Drawing the line straight to the customer
    // during that phase showed a route the driver was never going to take,
    // and an ETA that ignored the restaurant stop entirely — so the customer
    // watched the marker move away from the line they had been shown.
    //
    // Facture orders invert the roles: the "pickup" is the customer's own
    // address (cash is collected there) and the drop-off is the payment
    // office, so the same leg logic applies with the two ends swapped.
    final beforePickup = order.status != OrderStatus.pickedUp &&
        order.status != OrderStatus.onTheWay;

    final pickupPoint = order.pickupAddress == null
        ? null
        : (
            lat: order.pickupAddress!.latitude,
            lng: order.pickupAddress!.longitude
          );
    final deliveryPoint = (
      lat: order.deliveryAddress.latitude,
      lng: order.deliveryAddress.longitude
    );

    final destination = isFacture
        ? (order.status == OrderStatus.onTheWay && pickupPoint != null
            ? pickupPoint
            : deliveryPoint)
        : (beforePickup && pickupPoint != null ? pickupPoint : deliveryPoint);

    // Fetch the route when driver location first becomes available, then
    // re-fetch whenever the drawn line would be stale: the destination
    // changed (facture's onTheWay → pickupAddress / pickedUp → deliveryAddress
    // switch — the old line would point at the wrong place entirely), or the
    // driver has moved more than _kRouteRefetchThresholdMeters from where the
    // last route was computed (deviation, wrong turn, or just having covered
    // real distance since it was drawn). Previously this ran exactly once per
    // screen instance and the line never updated again for the rest of the
    // delivery, even though the live marker kept moving correctly.
    final destinationChanged = _lastRouteFetchDestination != destination;
    // Re-route on *deviation*, not on distance travelled. A driver following
    // the drawn line stays within GPS noise of it however far they go, so no
    // call is made; a driver who turns down a different street is off the
    // line within a block and the route is redrawn immediately — which is
    // what makes the customer see the new streets they are actually taking.
    final wentAnotherWay = showMap &&
        RouteFreshness.isOffRoute(
          _routePolyline,
          (lat: _driverLat!, lng: _driverLng!),
        );
    // A destination change is wrong outright, so it bypasses the rate limit;
    // deviation re-routes are throttled so a noisy GPS track cannot spam the
    // Directions API.
    final rateLimitPassed = _lastRouteFetchAt == null ||
        DateTime.now().difference(_lastRouteFetchAt!) >
            RouteFreshness.kMinRefetchInterval;
    if (showMap &&
        !_routeFetchInFlight &&
        (destinationChanged || (wentAnotherWay && rateLimitPassed))) {
      _fetchRoute(
        origin: (lat: _driverLat!, lng: _driverLng!),
        destination: destination,
      );
    }

    // Frame driver + the CURRENT destination, and reframe when the leg flips.
    //
    // Fitting once meant that the moment the driver collected the order and
    // turned towards the customer, the camera stayed framed on the restaurant
    // — the customer watched their driver head off the edge of the map.
    // Keying the guard on the destination re-fits exactly on that transition
    // and not on every GPS tick, so panning is still left to the user.
    if (showMap && _fittedForLeg != destination) {
      _fittedForLeg = destination;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.fitBounds([
          (lat: _driverLat!, lng: _driverLng!),
          destination,
        ]);
      });
    }

    // Center the very first frame between the driver's starting point and
    // the client's own address (destination), rather than only on the
    // client — otherwise the first paint shows just the client's location
    // and visibly jumps once fitBounds' post-frame animation catches up. A
    // wider initial zoom means both pins are likely already in view even
    // before that animation finishes.
    final initialCenter = showMap
        ? (
            lat: (_driverLat! + destination.lat) / 2,
            lng: (_driverLng! + destination.lng) / 2,
          )
        : destination;

    return Scaffold(
      body: Stack(
        children: [
          // Live map once the driver sends a position, else a big icon.
          if (showMap)
            AppMap(
              controller: _mapController,
              initialLatitude: initialCenter.lat,
              initialLongitude: initialCenter.lng,
              initialZoom: 12,
              polyline: _routePolyline,
              // The details sheet covers the lower ~45% of the screen; telling
              // the map about it keeps Google's own controls clear of the
              // sheet and centres the fitted route in the part still visible.
              contentPadding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.45,
              ),
              markers: {
                AppMapMarker(
                  id: 'delivery',
                  latitude: order.deliveryAddress.latitude,
                  longitude: order.deliveryAddress.longitude,
                  kind: AppMapMarkerKind.delivery,
                  title: isFacture
                      ? AppLocalizations.of(context)!.paymentOffice
                      : AppLocalizations.of(context)!.deliveryLocation,
                ),
                if ((isCourier || isFacture) && order.pickupAddress != null)
                  AppMapMarker(
                    id: 'pickup',
                    latitude: order.pickupAddress!.latitude,
                    longitude: order.pickupAddress!.longitude,
                    kind: AppMapMarkerKind.pickup,
                    title: isFacture ? AppLocalizations.of(context)!.yourAddress : AppLocalizations.of(context)!.pickupLocation,
                  ),
                AppMapMarker(
                  id: 'driver',
                  latitude: _driverLat!,
                  longitude: _driverLng!,
                  kind: AppMapMarkerKind.driver,
                  title: order.driverName ?? AppLocalizations.of(context)!.driverLabel,
                  bearing: _driverBearing,
                ),
              },
            )
          else
            _MapPlaceholder(
              icon: isFacture
                  ? Icons.receipt_long_rounded
                  : isCourier
                      ? Icons.local_shipping
                      : Icons.restaurant,
            ),

          const _BackButton(),

          // Recenter: the camera does not follow every GPS tick, so this
          // snaps back to a framed driver + destination view.
          if (showMap)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.45 + 16,
              child: _RecenterButton(
                onTap: () => _mapController.fitBounds([
                  (lat: _driverLat!, lng: _driverLng!),
                  destination,
                ]),
              ),
            ),

          TrackingDetailsSheet(
            order: order,
            route: showMap ? _route : null,
            shopName: shopName,
            items: items,
            // The shop's category decides, not the order type: checkout tags
            // "food" everything that is not grocery. Until the details are
            // loaded, keep the old behaviour.
            hasPreparationStep:
                ref.watch(hasPreparationStepProvider(shopCategory)) ??
                    (order.type == OrderType.food),
            onCancel: () => _showCancelDialog(order),
            onConfirmRecipientReceipt: _confirmReceipt,
            // Rebuild so the shop-rating prompt held back above gets its turn.
            onReceiptFlowFinished: () {
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

/// Big faint icon where the map will be, until the driver shares a position.
class _MapPlaceholder extends StatelessWidget {
  final IconData icon;

  const _MapPlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Icon(
          icon,
          size: 100,
          color: AppColors.textLight.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Round white ← at the top left.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round white ◎ button above the panel that re-frames the map.
class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}
