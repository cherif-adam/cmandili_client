import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/core/services/route_freshness.dart';

void main() {
  // A short north-bound segment in Sousse, then a right turn heading east.
  const route = <({double lat, double lng})>[
    (lat: 35.8250, lng: 10.6350),
    (lat: 35.8300, lng: 10.6350),
    (lat: 35.8300, lng: 10.6450),
  ];

  group('distanceToRouteMeters', () {
    test('is ~0 for a point exactly on a vertex', () {
      expect(
        RouteFreshness.distanceToRouteMeters(route, (lat: 35.8300, lng: 10.6350)),
        lessThan(1),
      );
    });

    test('is ~0 mid-segment, not just at vertices', () {
      // Halfway up the first leg — a vertex-only check would wrongly report
      // this as hundreds of meters off route.
      expect(
        RouteFreshness.distanceToRouteMeters(route, (lat: 35.8275, lng: 10.6350)),
        lessThan(1),
      );
    });

    test('measures perpendicular offset from the line', () {
      // ~0.0009 deg of longitude east of the first leg at this latitude is
      // roughly 81 m.
      final d = RouteFreshness.distanceToRouteMeters(
        route,
        (lat: 35.8275, lng: 10.6359),
      );
      expect(d, greaterThan(60));
      expect(d, lessThan(100));
    });
  });

  group('isOffRoute', () {
    test('driver on the line is not off route', () {
      expect(
        RouteFreshness.isOffRoute(route, (lat: 35.8275, lng: 10.6350)),
        isFalse,
      );
    });

    test('small GPS jitter does not trigger a re-route', () {
      // ~20 m sideways: well inside urban GPS error, must not re-route.
      expect(
        RouteFreshness.isOffRoute(route, (lat: 35.8275, lng: 10.63522)),
        isFalse,
      );
    });

    test('taking a different street does trigger a re-route', () {
      // ~180 m east of the drawn line: a genuinely different road.
      expect(
        RouteFreshness.isOffRoute(route, (lat: 35.8275, lng: 10.6370)),
        isTrue,
      );
    });

    test('a null or degenerate route always needs fetching', () {
      expect(RouteFreshness.isOffRoute(null, (lat: 35.8275, lng: 10.6350)), isTrue);
      expect(
        RouteFreshness.isOffRoute(
          [(lat: 35.8250, lng: 10.6350)],
          (lat: 35.8250, lng: 10.6350),
        ),
        isTrue,
      );
    });
  });

}
