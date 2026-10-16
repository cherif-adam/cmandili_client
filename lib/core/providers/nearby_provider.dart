import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/location_service.dart';

/// Customers see only the shops within this distance of where they are.
///
/// Straight-line distance: a circle around the customer. It is the same
/// answer whatever the traffic, and cheap enough to run on every shop of
/// every list.
const double kShopRadiusKm = 15;

typedef GeoPoint = ({double lat, double lng});

/// Whether a shop at [lat], [lng] is listed for a customer at [me].
///
/// - Customer position unknown (location refused or off, and no saved
///   address): every shop is listed. An empty app would be worse than a
///   long list.
/// - Shop without a position (0, 0 — what an unset column reads as): not
///   listed, since nobody can say it is within reach.
bool isWithinShopRadius(GeoPoint? me, double lat, double lng) {
  if (me == null) return true;
  final km = distanceKmFrom(me, lat, lng);
  return km != null && km <= kShopRadiusKm;
}

/// Straight-line distance from the customer to a shop, in km. `null` when
/// either position is unknown.
double? distanceKmFrom(GeoPoint? me, double lat, double lng) {
  if (me == null) return null;
  if (lat == 0 && lng == 0) return null;
  return Geolocator.distanceBetween(me.lat, me.lng, lat, lng) / 1000;
}

/// "650 m", "2,3 km", "12 km" — written the Tunisian way, like the prices.
String formatDistanceKm(double km) {
  // Rounded first, then the unit chosen, so 0.996 km reads "1,0 km" (not
  // "1000 m") and 9.96 km reads "10 km" (not "10,0 km").
  final metres = (km * 100).round() * 10; // to the nearest 10 m
  if (metres < 1000) return '${metres < 10 ? 10 : metres} m';
  final tenths = (km * 10).round();
  if (tenths < 100) {
    return '${NumberFormat('0.0', 'fr_TN').format(tenths / 10)} km';
  }
  return '${km.round()} km';
}

/// [shops] reduced to those within [kShopRadiusKm] of the customer,
/// nearest first.
///
/// Stays loading until the customer's position is known, so a far shop
/// never shows for a second and then disappears. Loading and error states
/// of [shops] pass through unchanged. With no position the list keeps its
/// own order, since there is nothing to measure from.
AsyncValue<List<T>> keepNearby<T>(
  AsyncValue<GeoPoint?> me,
  AsyncValue<List<T>> shops,
  GeoPoint Function(T shop) positionOf,
) {
  if (!me.hasValue) return AsyncLoading<List<T>>();
  final point = me.value;
  return shops.whenData((list) {
    final near = [
      for (final shop in list)
        if (isWithinShopRadius(
            point, positionOf(shop).lat, positionOf(shop).lng))
          shop,
    ];
    if (point == null) return near;
    double km(T shop) {
      final p = positionOf(shop);
      return distanceKmFrom(point, p.lat, p.lng) ?? double.infinity;
    }

    // Stable: two shops at the same distance keep the list's own order.
    final indexed = near.asMap().entries.toList()
      ..sort((a, b) {
        final byDistance = km(a.value).compareTo(km(b.value));
        return byDistance != 0 ? byDistance : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  });
}

/// The distance label for a shop card, or `null` while the customer's
/// position is unknown (the card then shows no distance at all).
final shopDistanceLabelProvider =
    Provider.family<String?, GeoPoint>((ref, shop) {
  final me = ref.watch(customerPositionProvider).valueOrNull;
  final km = distanceKmFrom(me, shop.lat, shop.lng);
  return km == null ? null : formatDistanceKm(km);
});

/// Where the customer is, for [kShopRadiusKm].
///
/// In order: the phone's last known fix (instant, so the lists do not wait
/// for the GPS), then a fresh fix, then the customer's default saved
/// address. `null` when none of them is available, and the lists then show
/// every shop (see [isWithinShopRadius]).
///
/// Loading only until the first answer. A later refresh — pull to refresh,
/// or coming back to the app after a while — keeps the current position and
/// replaces it only when a new one arrives, so the lists never drop back to
/// a spinner.
final customerPositionProvider =
    StateNotifierProvider<CustomerPositionNotifier, AsyncValue<GeoPoint?>>(
        (ref) => CustomerPositionNotifier());

class CustomerPositionNotifier extends StateNotifier<AsyncValue<GeoPoint?>> {
  CustomerPositionNotifier() : super(const AsyncLoading()) {
    // Someone who left the app open in one town and comes back to it in
    // another should see the shops where they are now.
    _lifecycle = AppLifecycleListener(onResume: () {
      final last = _lastRefresh;
      if (last == null ||
          DateTime.now().difference(last) > _resumeRefreshAfter) {
        refresh();
      }
    });
    refresh();
  }

  static const _resumeRefreshAfter = Duration(minutes: 5);
  static const _fixTimeout = Duration(seconds: 12);

  late final AppLifecycleListener _lifecycle;
  DateTime? _lastRefresh;
  Future<void>? _inFlight;

  Future<void> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<void> _refresh() async {
    _lastRefresh = DateTime.now();
    var known = false;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _set((lat: last.latitude, lng: last.longitude));
          known = true;
        }
      }
    } catch (_) {}

    try {
      // Asks for the permission the first time.
      final fresh = await LocationService.getCurrentPosition()
          .timeout(_fixTimeout, onTimeout: () => null);
      if (fresh != null) {
        _set((lat: fresh.latitude, lng: fresh.longitude));
        return;
      }
    } catch (_) {}
    if (known) return;

    final saved = await _savedAddress();
    if (saved != null) {
      _set(saved);
    } else if (!state.hasValue) {
      _set(null);
    }
  }

  /// The default saved address, else the first one with real coordinates.
  Future<GeoPoint?> _savedAddress() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      final rows = await client
          .from('user_addresses')
          .select('latitude, longitude')
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: true);
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final lat = (row['latitude'] as num?)?.toDouble() ?? 0;
        final lng = (row['longitude'] as num?)?.toDouble() ?? 0;
        if (lat != 0 || lng != 0) return (lat: lat, lng: lng);
      }
    } catch (_) {}
    return null;
  }

  void _set(GeoPoint? point) {
    if (mounted) state = AsyncData(point);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }
}

/// Every shop's position, for lists that carry a shop id but no
/// coordinates (the happy hour deals).
final shopPositionsProvider =
    FutureProvider<Map<String, GeoPoint>>((ref) async {
  final rows = await Supabase.instance.client
      .from('vendors')
      .select('id, latitude, longitude');
  return {
    for (final row in (rows as List).cast<Map<String, dynamic>>())
      row['id'] as String: (
        lat: (row['latitude'] as num?)?.toDouble() ?? 0,
        lng: (row['longitude'] as num?)?.toDouble() ?? 0,
      ),
  };
});

/// Ids of the shops within [kShopRadiusKm] of the customer.
///
/// `null` means "do not filter": the customer's position is unknown, or the
/// shop positions could not be read. Empty while either is still loading,
/// for the same reason as [keepNearby].
final nearbyShopIdsProvider = Provider<Set<String>?>((ref) {
  final me = ref.watch(customerPositionProvider);
  if (!me.hasValue) return const <String>{};
  final point = me.value;
  if (point == null) return null;

  final shops = ref.watch(shopPositionsProvider);
  final positions = shops.valueOrNull;
  if (positions == null) return shops.hasError ? null : const <String>{};
  return {
    for (final entry in positions.entries)
      if (isWithinShopRadius(point, entry.value.lat, entry.value.lng))
        entry.key,
  };
});
