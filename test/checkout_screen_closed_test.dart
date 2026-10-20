// Passer commande — le client ferme l'écran pendant que la commande part.
//
// Règle : une fois « Commander » touché, la commande va au bout ou tout est
// défait, que l'écran soit encore là ou non. Jamais d'état à moitié fait :
//   • code promo consommé sans commande,
//   • commande créée mais jamais payée,
//   • paiement refusé sans annulation de la commande ni restitution du code.
//
// Chaque test met la commande en pause à une étape (un faux dépôt attend un
// signal), ferme l'écran, laisse passer une image (le contrôleur de l'écran
// est alors libéré), puis débloque l'étape et regarde où tout a fini.
//
// Le paiement cash n'a pas besoin d'écran : une commande dont l'écran a été
// fermé est donc payée et le panier vidé, comme si le client était resté.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/core/models/vendor.dart';
import 'package:cmandili_mobile/core/payment/payment_gateway.dart';
import 'package:cmandili_mobile/core/payment/payment_service.dart';
import 'package:cmandili_mobile/features/cart/data/models/cart_item.dart';
import 'package:cmandili_mobile/features/cart/providers/cart_provider.dart';
import 'package:cmandili_mobile/features/checkout/data/checkout_repository.dart';
import 'package:cmandili_mobile/features/checkout/data/models/delivery_address.dart';
import 'package:cmandili_mobile/features/checkout/presentation/address_selection/address_selection_screen.dart';
import 'package:cmandili_mobile/features/checkout/presentation/checkout/checkout_controller.dart';
import 'package:cmandili_mobile/features/checkout/presentation/checkout/checkout_screen.dart';
import 'package:cmandili_mobile/features/orders/data/models/order.dart';
import 'package:cmandili_mobile/features/orders/data/order_repository.dart';
import 'package:cmandili_mobile/features/orders/providers/order_provider.dart';
import 'package:cmandili_mobile/features/promo/data/models/promo_code_response.dart';
import 'package:cmandili_mobile/features/promo/data/promo_repository.dart';
import 'package:cmandili_mobile/features/promo/providers/promo_provider.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

// ── Pauses ───────────────────────────────────────────────────────────────────

enum _Step { venueCheck, promoCommit, createOrder, payment, cancelOrder }

/// Holds one step until the test lets it go.
class _Gate {
  final _release = Completer<void>();
  bool reached = false;

  Future<void> hold() async {
    reached = true;
    await _release.future;
  }

  void open() => _release.complete();
}

class _Gates {
  _Gates(this.held) : _gates = {for (final s in held) s: _Gate()};

  final Set<_Step> held;
  final Map<_Step, _Gate> _gates;

  _Gate operator [](_Step step) => _gates[step]!;

  Future<void> pass(_Step step) async => _gates[step]?.hold();
}

// ── Faux dépôts ──────────────────────────────────────────────────────────────

class _FakeCheckoutRepository extends CheckoutRepository {
  _FakeCheckoutRepository(this.gates);

  final _Gates gates;

  @override
  Future<bool?> vendorIsOpen(String vendorId) async {
    await gates.pass(_Step.venueCheck);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> vendorPickupRow(String vendorId) async =>
      {'latitude': null, 'longitude': null, 'category': 'food'};
}

class _FakePromoRepository extends PromoRepository {
  _FakePromoRepository(this.gates);

  final _Gates gates;
  final applied = <String>[];
  final released = <String>[];

  @override
  Future<PromoCodeResponse> validatePromoCode({
    required String promoCode,
    required List<CartItem> items,
  }) async =>
      const PromoCodeResponse(isSuccess: true, discountAmount: 4, newSubtotal: 16);

  @override
  Future<PromoCodeResponse> applyPromoCode({
    required String promoCode,
    required List<CartItem> items,
  }) async {
    applied.add(promoCode);
    await gates.pass(_Step.promoCommit);
    return const PromoCodeResponse(
        isSuccess: true, discountAmount: 4, newSubtotal: 16);
  }

  @override
  Future<void> releaseUsage({required String promoCode}) async {
    released.add(promoCode);
  }
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository(this.gates, {this.createFails = false});

  final _Gates gates;
  final bool createFails;
  final createdSubtotals = <double>[];
  final cancelled = <String>[];

  @override
  Future<
      ({
        String orderId,
        double deliveryFee,
        double total,
        String? loyaltyMilestoneType,
        double loyaltyDiscountAmount,
      })> createOrder({
    required List<CartItem> items,
    required DeliveryAddress deliveryAddress,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required OrderType orderType,
    String? restaurantId,
    String? supermarketId,
    String? notes,
    String paymentMethod = 'cash',
    double? distanceKm,
    DateTime? estimatedDeliveryTime,
  }) async {
    await gates.pass(_Step.createOrder);
    if (createFails) throw Exception('réseau coupé pendant la création');
    createdSubtotals.add(subtotal);
    return (
      orderId: 'o-9',
      deliveryFee: deliveryFee,
      total: subtotal + deliveryFee,
      loyaltyMilestoneType: null,
      loyaltyDiscountAmount: 0.0,
    );
  }

  @override
  Future<bool> cancelOrder(String orderId) async {
    await gates.pass(_Step.cancelOrder);
    cancelled.add(orderId);
    return true;
  }
}

/// Paiement cash simulé (pas de ligne `payments` en test) ; [refuse] fait
/// répondre « refusé ».
class _FakePaymentService extends PaymentService {
  _FakePaymentService(this.gates, {this.refuse = false});

  final _Gates gates;
  final bool refuse;
  final paid = <({String orderId, double amount})>[];

  @override
  Future<PaymentResult> processAndRecord({
    required String orderId,
    required double amount,
    required String methodKey,
    required BuildContext? context,
  }) async {
    await gates.pass(_Step.payment);
    if (refuse) return const PaymentResult(success: false);
    paid.add((orderId: orderId, amount: amount));
    return const PaymentResult(success: true, rawPayload: {'method': 'cash'});
  }
}

// ── Écran et gestes ──────────────────────────────────────────────────────────

final _address = DeliveryAddress(
  id: 'a1',
  label: 'Maison',
  fullAddress: 'Avenue Habib Bourguiba, Kairouan',
  latitude: 35.67,
  longitude: 10.1,
);

CartItem _line() => CartItem.vendor(
      vendorItem: const VendorItem(
        id: 'i1',
        vendorId: 'v1',
        name: 'Pizza margherita',
        description: 'Tomate, mozzarella',
        imageUrl: '',
        price: 20,
      ),
    );

Finder _byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

class _World {
  _World(this.container, this.show, this.gates, this.orders, this.promos,
      this.payments, this.l);

  final ProviderContainer container;
  final ValueNotifier<bool> show;
  final _Gates gates;
  final _FakeOrderRepository orders;
  final _FakePromoRepository promos;
  final _FakePaymentService payments;
  final AppLocalizations l;

  List<CartItem> get cart => container.read(cartProvider);
}

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_World> _pump(
  WidgetTester tester, {
  required Set<_Step> holdAt,
  bool createFails = false,
  bool refusePayment = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  // Large : la police de test fait déborder l'en-tête des adresses à 393 px.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final gates = _Gates(holdAt);
  final orders = _FakeOrderRepository(gates, createFails: createFails);
  final promos = _FakePromoRepository(gates);
  final payments = _FakePaymentService(gates, refuse: refusePayment);
  final container = ProviderContainer(overrides: [
    checkoutRepositoryProvider.overrideWithValue(_FakeCheckoutRepository(gates)),
    orderRepositoryProvider.overrideWithValue(orders),
    promoRepositoryProvider.overrideWithValue(promos),
    paymentServiceProvider.overrideWithValue(payments),
    orderStreamProvider
        .overrideWith((ref, id) => StreamController<Order>().stream),
  ]);
  addTearDown(container.dispose);
  container.read(cartProvider.notifier).addItem(_line());

  final show = ValueNotifier(true);
  addTearDown(show.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, visible, __) => visible
            ? const CheckoutScreen(subtotal: 20, deliveryFee: 3.5, total: 23.5)
            : const Scaffold(body: Text('accueil')),
      ),
    ),
  ));
  await tester.pump();
  final l = await AppLocalizations.delegate.load(const Locale('fr'));

  // Adresse, contact, et éventuellement l'aperçu du code promo.
  await tester.tap(_byTypeName('CheckoutAddressPicker'));
  await _frames(tester);
  Navigator.of(tester.element(find.byType(AddressSelectionScreen)))
      .pop(_address);
  await _frames(tester);
  await tester.enterText(find.widgetWithText(TextField, l.fullNameHint), 'Sami');
  await tester.enterText(find.widgetWithText(TextField, l.phoneHint), '22123456');
  await tester.pump();

  return _World(container, show, gates, orders, promos, payments, l);
}

Future<void> _previewPromo(WidgetTester tester, AppLocalizations l) async {
  final field = find.widgetWithText(TextField, l.promoCodePlaceholder);
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, 'promo10');
  final apply = find.widgetWithText(ElevatedButton, l.applyPromoCode);
  await tester.ensureVisible(apply);
  await _frames(tester);
  await tester.tap(apply);
  await _frames(tester);
}

/// Touche « Commander », attend que la commande soit en pause à [step],
/// ferme l'écran, laisse le contrôleur se libérer, puis débloque l'étape.
Future<void> _placeAndCloseAt(WidgetTester tester, _World w, _Step step) async {
  await tester.tap(find.descendant(
      of: _byTypeName('PlaceOrderBar'), matching: find.byType(ElevatedButton)));
  await tester.pump();
  for (var i = 0; i < 40 && !w.gates[step].reached; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(w.gates[step].reached, isTrue, reason: 'la commande n\'a pas atteint $step');

  w.show.value = false;
  await tester.pump();
  await _frames(tester, 3);
  expect(find.byType(CheckoutScreen), findsNothing);

  w.gates[step].open();
  await _frames(tester, 10);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
      httpClient: MockClient((req) async => http.Response('[]', 200,
          headers: {'content-type': 'application/json'}, request: req)),
    );
  });
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  void expectPlacedAndPaid(_World w) {
    expect(w.orders.createdSubtotals, hasLength(1),
        reason: 'la commande doit être créée');
    expect(w.payments.paid, hasLength(1), reason: 'et payée');
    expect(w.payments.paid.single.orderId, 'o-9');
    expect(w.orders.cancelled, isEmpty);
    expect(w.cart, isEmpty, reason: 'le panier est vidé une fois payé');
  }

  testWidgets('fermé pendant le contrôle d\'ouverture : la commande va au bout',
      (tester) async {
    final w = await _pump(tester, holdAt: {_Step.venueCheck});
    await _placeAndCloseAt(tester, w, _Step.venueCheck);

    expectPlacedAndPaid(w);
    expect(w.orders.createdSubtotals.single, 20);
  });

  testWidgets(
      'fermé pendant la consommation du code : la commande part avec la '
      'remise, le code reste consommé', (tester) async {
    final w = await _pump(tester, holdAt: {_Step.promoCommit});
    await _previewPromo(tester, w.l);
    await _placeAndCloseAt(tester, w, _Step.promoCommit);

    expect(w.promos.applied, ['PROMO10']);
    expectPlacedAndPaid(w);
    expect(w.orders.createdSubtotals.single, 16);
    expect(w.promos.released, isEmpty, reason: 'une commande l\'utilise');
  });

  testWidgets('fermé pendant la création : la commande est quand même payée',
      (tester) async {
    final w = await _pump(tester, holdAt: {_Step.createOrder});
    await _placeAndCloseAt(tester, w, _Step.createOrder);

    expectPlacedAndPaid(w);
  });

  testWidgets(
      'fermé pendant une création qui échoue : le code consommé est rendu',
      (tester) async {
    final w =
        await _pump(tester, holdAt: {_Step.createOrder}, createFails: true);
    await _previewPromo(tester, w.l);
    await _placeAndCloseAt(tester, w, _Step.createOrder);

    expect(w.promos.applied, ['PROMO10']);
    expect(w.orders.createdSubtotals, isEmpty);
    expect(w.payments.paid, isEmpty);
    expect(w.promos.released, ['PROMO10']);
    expect(w.cart, hasLength(1), reason: 'rien n\'a été commandé');
  });

  testWidgets(
      'fermé pendant un paiement refusé : commande annulée et code rendu',
      (tester) async {
    final w =
        await _pump(tester, holdAt: {_Step.payment}, refusePayment: true);
    await _previewPromo(tester, w.l);
    await _placeAndCloseAt(tester, w, _Step.payment);

    expect(w.orders.createdSubtotals, hasLength(1));
    expect(w.payments.paid, isEmpty);
    expect(w.orders.cancelled, ['o-9']);
    expect(w.promos.released, ['PROMO10']);
    expect(w.cart, hasLength(1));
  });

  testWidgets(
      'fermé pendant l\'annulation après un refus : le code est quand même '
      'rendu', (tester) async {
    final w =
        await _pump(tester, holdAt: {_Step.cancelOrder}, refusePayment: true);
    await _previewPromo(tester, w.l);
    await _placeAndCloseAt(tester, w, _Step.cancelOrder);

    expect(w.orders.cancelled, ['o-9']);
    expect(w.promos.released, ['PROMO10']);
    expect(w.cart, hasLength(1));
  });
}
