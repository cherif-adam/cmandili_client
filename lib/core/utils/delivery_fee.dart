import 'location_service.dart';

/// Platform delivery fee constants.
///
/// Base fee:   3.500 TND — covers the first [_kThresholdKm] kilometres.
/// Threshold:  3 km       — no surcharge up to this distance.
/// Surcharge:  0.500 TND per km beyond the threshold.
///
/// Examples:
///   2.5 km → 3.500 TND
///   4.0 km → 4.000 TND  (3.500 + 1.0 × 0.500)
///   4.5 km → 4.250 TND  (3.500 + 1.5 × 0.500)
const double kDeliveryBaseFee = 3.5;
const double _kThresholdKm = 3.0;
const double _kPerKmSurcharge = 0.5;

/// Computes the customer-facing delivery fee.
///
/// [partnerFlatFee] defaults to [kDeliveryBaseFee] (the platform base for
/// restaurant and supermarket orders). Pass a different value for special
/// order types (courier = 5 DT, bill payment = 2 DT) — the platform base
/// still acts as the floor so the fee is always ≥ [kDeliveryBaseFee].
///
/// When [distanceKm] is null the base fee is returned as-is; the exact fee
/// is re-computed at checkout once the delivery address is known.
double calculateDeliveryFee({
  double partnerFlatFee = kDeliveryBaseFee,
  double? distanceKm,
}) {
  final extraKm = (distanceKm ?? 0) - _kThresholdKm;
  final surcharge = extraKm > 0 ? extraKm * _kPerKmSurcharge : 0.0;
  final candidate = partnerFlatFee + surcharge;
  return candidate < kDeliveryBaseFee ? kDeliveryBaseFee : candidate;
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
