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

/// Flat, distance-independent fee for supermarket and bill-payment (facture)
/// orders. These two are priced per-trip rather than per-kilometre: a
/// supermarket run means the driver shops in store, and a facture means they
/// queue at a payment office — the time cost has little to do with how far
/// they drove, so the distance formula never applied well to either.
const double kFlatDeliveryFee = 5.0;

/// Computes the customer-facing delivery fee.
///
/// Two pricing modes:
///   - distance-based (default) — food and courier: [kDeliveryBaseFee] covers
///     the first [_kThresholdKm] km, then [_kPerKmSurcharge] per extra km.
///   - flat ([isFlatRate]) — supermarket and facture: [partnerFlatFee] exactly,
///     ignoring distance. Note this bypasses the [kDeliveryBaseFee] floor,
///     which is intentional: the floor exists to stop a distance calculation
///     undercutting the base, and a flat price is a deliberate figure, not a
///     computed one.
///
/// When [distanceKm] is null in distance-based mode the base fee is returned
/// as-is; the exact fee is re-computed at checkout once the address is known.
double calculateDeliveryFee({
  double partnerFlatFee = kDeliveryBaseFee,
  double? distanceKm,
  bool isFlatRate = false,
}) {
  if (isFlatRate) return partnerFlatFee;
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
