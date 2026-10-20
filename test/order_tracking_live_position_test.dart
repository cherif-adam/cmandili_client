// Suivi de commande — les deux sources temps réel du livreur.
//
// L'écran suit le livreur par deux flux : la ligne `deliveries` de la
// commande, puis, dès qu'un livreur est assigné, sa ligne `drivers`. Un
// abonnement oublié continue de recevoir chaque position GPS (environ une par
// seconde) après la fermeture de l'écran, pour rien. Ces tests prouvent que
// les deux flux sont annulés au moment où l'écran se ferme, et que la logique
// de position (point (0,0) ignoré, cap calculé seulement après un vrai
// déplacement, nouveau livreur → ancien flux coupé) est restée la même en
// passant de l'écran au contrôleur.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/core/models/vendor.dart';
import 'package:cmandili_mobile/core/providers/vendor_provider.dart';
import 'package:cmandili_mobile/core/widgets/app_map.dart';
import 'package:cmandili_mobile/features/checkout/data/models/delivery_address.dart';
import 'package:cmandili_mobile/features/orders/data/models/order.dart';
import 'package:cmandili_mobile/features/orders/data/order_live_repository.dart';
import 'package:cmandili_mobile/features/orders/data/order_rating_repository.dart';
import 'package:cmandili_mobile/features/orders/presentation/order_tracking/order_tracking_controller.dart';
import 'package:cmandili_mobile/features/orders/presentation/order_tracking/order_tracking_screen.dart';
import 'package:cmandili_mobile/features/orders/providers/order_provider.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

typedef _Rows = List<Map<String, dynamic>>;

/// Dépôt sans réseau : chaque flux est un StreamController dont on sait s'il
/// est encore écouté.
class _FakeOrderRepository extends OrderLiveRepository {
  final deliveries = <String, StreamController<_Rows>>{};
  final drivers = <String, StreamController<_Rows>>{};
  final cancelled = <String>[];

  @override
  Stream<_Rows> streamDeliveryRows(String orderId) {
    final c = StreamController<_Rows>(
        onCancel: () => cancelled.add('deliveries:$orderId'));
    deliveries[orderId] = c;
    return c.stream;
  }

  @override
  Stream<_Rows> streamDriverRows(String driverId) {
    final c =
        StreamController<_Rows>(onCancel: () => cancelled.add('drivers:$driverId'));
    drivers[driverId] = c;
    return c.stream;
  }
}

/// La feuille de suivi demande si le livreur peut être noté : non, sans réseau.
class _NoDriverRating extends OrderRatingRepository {
  @override
  Future<bool> canRateDriver(String orderId) async => false;
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final _order = Order(
  id: 'o1',
  userId: 'u1',
  restaurantName: 'Seven Pizza',
  deliveryAddress: DeliveryAddress(
    id: 'a1',
    label: 'Maison',
    fullAddress: 'Avenue Habib Bourguiba, Kairouan',
    latitude: 35.67,
    longitude: 10.1,
  ),
  subtotal: 20,
  deliveryFee: 3,
  total: 23,
  status: OrderStatus.pending,
  createdAt: DateTime(2026, 10, 20, 12),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // OrderLiveRepository() résout Supabase.instance.client dans son
    // constructeur, y compris pour le faux dépôt.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
    );
  });

  group('contrôleur', () {
    late _FakeOrderRepository repo;
    late ProviderContainer container;
    late AutoDisposeFamilyNotifierProvider<OrderTrackingController,
        OrderTrackingState, Object> provider;
    late ProviderSubscription<OrderTrackingState> keepAlive;

    setUp(() {
      repo = _FakeOrderRepository();
      container = ProviderContainer(
          overrides: [orderLiveRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      provider = orderTrackingControllerProvider(Object());
      // Ce que fait l'écran en s'affichant : il écoute son contrôleur.
      keepAlive = container.listen(provider, (_, __) {});
      container.read(provider.notifier).followDriver('o1');
    });

    OrderTrackingState read() => container.read(provider);

    test('suit la ligne deliveries de la commande, et elle seule', () {
      expect(repo.deliveries.keys, ['o1']);
      expect(repo.deliveries['o1']!.hasListener, isTrue);
      expect(repo.drivers, isEmpty);
    });

    test('le point (0,0) d\'une livraison tout juste acceptée est ignoré',
        () async {
      repo.deliveries['o1']!
          .add([{'driver_id': 'd1', 'current_lat': 0, 'current_lng': 0}]);
      await _flush();
      expect(read().hasValidPosition, isFalse);
      expect(read().driverLat, isNull);
      // Le livreur est quand même suivi par sa propre ligne.
      expect(repo.drivers.keys, ['d1']);
      expect(repo.drivers['d1']!.hasListener, isTrue);
    });

    test('le cap n\'apparaît qu\'après un vrai déplacement', () async {
      repo.deliveries['o1']!.add([{'driver_id': 'd1'}]);
      await _flush();
      repo.drivers['d1']!.add([{'current_lat': 35.67, 'current_lng': 10.10}]);
      await _flush();
      expect(read().driverLat, 35.67);
      expect(read().driverLng, 10.10);
      expect(read().driverBearing, isNull, reason: 'une seule position');

      // Bruit GPS (moins de ~5 m) : la position bouge, pas le cap.
      repo.drivers['d1']!
          .add([{'current_lat': 35.67001, 'current_lng': 10.10001}]);
      await _flush();
      expect(read().driverLat, 35.67001);
      expect(read().driverBearing, isNull);

      // Vrai déplacement, reçu cette fois par la ligne deliveries.
      repo.deliveries['o1']!
          .add([{'driver_id': 'd1', 'current_lat': 35.68, 'current_lng': 10.11}]);
      await _flush();
      expect(read().driverLat, 35.68);
      expect(
        read().driverBearing,
        bearingBetween((lat: 35.67001, lng: 10.10001), (lat: 35.68, lng: 10.11)),
      );
      // Même livreur : pas de second abonnement.
      expect(repo.drivers.keys, ['d1']);

      // Une position invalide plus tard ne fait rien bouger.
      repo.drivers['d1']!.add([{'current_lat': null, 'current_lng': 10.2}]);
      await _flush();
      expect(read().driverLat, 35.68);
    });

    test('un nouveau livreur coupe le flux de l\'ancien', () async {
      repo.deliveries['o1']!.add([{'driver_id': 'd1'}]);
      await _flush();
      repo.deliveries['o1']!.add([{'driver_id': 'd2'}]);
      await _flush();
      expect(repo.cancelled, ['drivers:d1']);
      expect(repo.drivers['d1']!.hasListener, isFalse);
      expect(repo.drivers['d2']!.hasListener, isTrue);
    });

    test('stopFollowing annule les deux flux et ignore ce qui arrive après',
        () async {
      repo.deliveries['o1']!.add([{'driver_id': 'd1'}]);
      await _flush();
      container.read(provider.notifier).stopFollowing();
      expect(repo.cancelled, unorderedEquals(['deliveries:o1', 'drivers:d1']));
      expect(repo.deliveries['o1']!.hasListener, isFalse);
      expect(repo.drivers['d1']!.hasListener, isFalse);
    });

    test('plus personne n\'écoute le contrôleur : il annule les deux flux',
        () async {
      repo.deliveries['o1']!.add([{'driver_id': 'd1'}]);
      await _flush();
      keepAlive.close();
      await _flush();
      expect(repo.cancelled, unorderedEquals(['deliveries:o1', 'drivers:d1']));
    });
  });

  testWidgets('fermer l\'écran annule les deux flux, dans la même image',
      (tester) async {
    final repo = _FakeOrderRepository();
    final show = ValueNotifier(true);
    addTearDown(show.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        orderLiveRepositoryProvider.overrideWithValue(repo),
        orderRatingRepositoryProvider.overrideWithValue(_NoDriverRating()),
        orderStreamProvider.overrideWith((ref, id) => Stream.value(_order)),
        orderDetailsProvider.overrideWith((ref, id) async => null),
        vendorCategoriesProvider
            .overrideWith((ref) async => VendorCategory.fallback),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, visible, __) => visible
              ? const OrderTrackingScreen(orderId: 'o1')
              : const SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(OrderTrackingScreen), findsOneWidget);

    // Un livreur accepte : la ligne drivers est suivie aussi.
    repo.deliveries['o1']!
        .add([{'driver_id': 'd1', 'current_lat': 0, 'current_lng': 0}]);
    await tester.pump();
    expect(repo.deliveries['o1']!.hasListener, isTrue);
    expect(repo.drivers['d1']!.hasListener, isTrue);
    expect(repo.cancelled, isEmpty);

    // L'écran se ferme : une seule image plus tard, plus rien n'écoute.
    show.value = false;
    await tester.pump();
    expect(find.byType(OrderTrackingScreen), findsNothing);
    expect(repo.cancelled, unorderedEquals(['deliveries:o1', 'drivers:d1']));
    expect(repo.deliveries['o1']!.hasListener, isFalse);
    expect(repo.drivers['d1']!.hasListener, isFalse);
  });
}
