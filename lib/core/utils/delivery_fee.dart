import 'location_service.dart';

/// Computes the customer-facing delivery fee for an order.
///
/// Rules (locked in with the partner — every order must clear this floor so
/// drivers always earn at least 3 DT, with a 0.5 DT/km bonus past 4 km):
///
///   - Base fee = `partnerFlatFee` (e.g. restaurants.delivery_fee, or 5 DT
///     for courier orders, 2 DT for bill payments). May be 0 if the partner
///     hasn't set one — that's fine, the floor still applies.
///   - Distance fee = 0.5 × max(0, distanceKm − 4)
///   - Final fee = max(3.0, base + distance)
///
/// Returns 3.0 when [distanceKm] is null (we don't know the customer's
/// location yet) so the cart can show a sensible preview before address
/// selection. Re-computed at order placement once the address is known.
double calculateDeliveryFee({
  required double partnerFlatFee,
  double? distanceKm,
}) {
  const minimum = 3.0;
  const distanceThresholdKm = 4.0;
  const perKmBonus = 0.5;

  final extraKm = (distanceKm ?? 0) - distanceThresholdKm;
  final distanceFee = extraKm > 0 ? extraKm * perKmBonus : 0;

  final candidate = partnerFlatFee + distanceFee;
  return candidate < minimum ? minimum : candidate.toDouble();
}

/// Distance helper that returns null when either side has missing/zero
/// coords. Used when we want to *try* to compute the bonus but degrade
/// gracefully rather than throw.
Future<double?> tryDistanceKm({
  required double? originLat,
  required double? originLng,
  required double? destLat,
  required double? destLng,
}) async {
    if (originLat == null || originLng == null || destLat == null || destLng == null) {
      return null;
    }
    if ((originLat == 0 && originLng == 0) || (destLat == 0 && destLng == 0)) {
      return null;
    }
    return await LocationService.calculateRouteDistance(originLat, originLng, destLat, destLng);
  }
