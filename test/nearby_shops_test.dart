import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/core/providers/nearby_provider.dart';

/// Shop positions as they are in the live `vendors` table (Oct 2026).
typedef _Shop = ({String name, double lat, double lng});

const List<_Shop> _shops = [
  (name: 'Seven pizza Kairouan', lat: 35.672844, lng: 10.1022918),
  (name: 'Piccolo Mondo', lat: 35.6843623, lng: 10.0972447),
  (name: 'Carrefour Market Kairouan', lat: 35.6735, lng: 10.0966),
  (name: 'Monoprix Sousse', lat: 35.8256, lng: 10.6369),
];

/// Central Kairouan.
const GeoPoint _kairouan = (lat: 35.6781, lng: 10.0994);

/// Central Sousse, about 55 km east.
const GeoPoint _sousse = (lat: 35.8256, lng: 10.6369);

List<String> _visible(GeoPoint? me) => [
      for (final s in _shops)
        if (isWithinShopRadius(me, s.lat, s.lng)) s.name,
    ];

void main() {
  test('the radius is 15 km', () {
    expect(kShopRadiusKm, 15);
  });

  test('a customer in Kairouan sees the Kairouan shops, not Sousse', () {
    expect(_visible(_kairouan), [
      'Seven pizza Kairouan',
      'Piccolo Mondo',
      'Carrefour Market Kairouan',
    ]);
  });

  test('a customer in Sousse sees only the Sousse shop', () {
    expect(_visible(_sousse), ['Monoprix Sousse']);
  });

  test('14 km away is shown, 16 km away is not', () {
    // Due north: one degree of latitude is about 111.2 km.
    const kmPerDegree = 111.2;
    final at14 = _kairouan.lat + 14 / kmPerDegree;
    final at16 = _kairouan.lat + 16 / kmPerDegree;
    expect(isWithinShopRadius(_kairouan, at14, _kairouan.lng), isTrue);
    expect(isWithinShopRadius(_kairouan, at16, _kairouan.lng), isFalse);
  });

  test('position unknown: every shop is shown rather than none', () {
    expect(_visible(null), hasLength(_shops.length));
  });

  test('a shop with no position (0, 0) is not shown', () {
    expect(isWithinShopRadius(_kairouan, 0, 0), isFalse);
  });

  group('keepNearby', () {
    GeoPoint at(_Shop s) => (lat: s.lat, lng: s.lng);

    test('filters the loaded list', () {
      final result = keepNearby<_Shop>(
        const AsyncData(_kairouan),
        const AsyncData(_shops),
        at,
      );
      expect(result.value!.map((s) => s.name),
          isNot(contains('Monoprix Sousse')));
      expect(result.value, hasLength(3));
    });

    test('stays loading until the customer position is known', () {
      final result = keepNearby<_Shop>(
        const AsyncLoading(),
        const AsyncData(_shops),
        at,
      );
      expect(result.isLoading, isTrue);
      expect(result.hasValue, isFalse);
    });

    test('position known to be unavailable: the whole list', () {
      final result = keepNearby<_Shop>(
        const AsyncData(null),
        const AsyncData(_shops),
        at,
      );
      expect(result.value, hasLength(_shops.length));
    });

    test('a list that failed to load stays an error', () {
      final result = keepNearby<_Shop>(
        const AsyncData(_kairouan),
        const AsyncError<List<_Shop>>('offline', StackTrace.empty),
        at,
      );
      expect(result.hasError, isTrue);
    });

    test('nearest shop first', () {
      final result = keepNearby<_Shop>(
        const AsyncData(_kairouan),
        const AsyncData(_shops),
        at,
      );
      // About 570 m, 640 m and 720 m from central Kairouan.
      expect(result.value!.map((s) => s.name), [
        'Carrefour Market Kairouan',
        'Seven pizza Kairouan',
        'Piccolo Mondo',
      ]);
    });

    test('no position: the list keeps its own order', () {
      final result = keepNearby<_Shop>(
        const AsyncData(null),
        const AsyncData(_shops),
        at,
      );
      expect(result.value, _shops);
    });
  });

  group('distance text', () {
    test('under 1 km in metres, to the nearest 10 m', () {
      expect(formatDistanceKm(0.574), '570 m');
      expect(formatDistanceKm(0.004), '10 m');
    });

    test('1 to 10 km with one decimal, Tunisian comma', () {
      expect(formatDistanceKm(2.34), '2,3 km');
      expect(formatDistanceKm(0.996), '1,0 km');
    });

    test('10 km and more in whole km', () {
      expect(formatDistanceKm(9.96), '10 km');
      expect(formatDistanceKm(14.4), '14 km');
    });

    test('a real shop: Carrefour Market from central Kairouan', () {
      final km = distanceKmFrom(_kairouan, 35.6735, 10.0966)!;
      expect(formatDistanceKm(km), endsWith(' m'));
      expect(km, closeTo(0.57, 0.03));
    });

    test('no distance when either position is unknown', () {
      expect(distanceKmFrom(null, 35.6735, 10.0966), isNull);
      expect(distanceKmFrom(_kairouan, 0, 0), isNull);
    });
  });
}
