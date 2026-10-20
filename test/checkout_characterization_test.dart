// Passer commande — ce que fait l'écran Commande aujourd'hui, figé avant son
// découpage en UI / contrôleur.
//
// Tests de CARACTÉRISATION : ils ne disent pas ce que le code devrait faire,
// ils enregistrent ce qu'il fait, pour qu'un remaniement qui change quoi que
// ce soit dans l'argent (code promo consommé, commande créée, paiement,
// annulation, panier vidé) casse un test au lieu de passer inaperçu.
//
// Les quatre chemins qui comptent :
//   1. commerce fermé au moment de payer : rien n'est consommé ni créé ;
//   2. code promo refusé au moment de le consommer : rien n'est créé, le
//      code est retiré de l'écran ;
//   3. paiement refusé : la commande créée est annulée ET le code promo
//      consommé est rendu ;
//   4. tout passe : la commande part avec les montants du serveur, le
//      paiement porte sur le total renvoyé, le panier est vidé et le suivi
//      s'ouvre.
//
// L'écran est piloté comme un client le ferait (adresse, téléphone, code,
// bouton). Les dépôts sont remplacés par des faux qui enregistrent ce qu'on
// leur demande ; les deux lectures que l'écran fait encore directement dans
// Supabase (commerce ouvert ? coordonnées du commerce ?) reçoivent une
// réponse HTTP préparée.

import 'dart:async';
import 'dart:convert';

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
import 'package:cmandili_mobile/core/utils/delivery_fee.dart';
import 'package:cmandili_mobile/features/cart/data/models/cart_item.dart';
import 'package:cmandili_mobile/features/cart/providers/cart_provider.dart';
import 'package:cmandili_mobile/features/checkout/data/models/delivery_address.dart';
import 'package:cmandili_mobile/features/checkout/presentation/address_selection/address_selection_screen.dart';
import 'package:cmandili_mobile/features/checkout/presentation/checkout/checkout_screen.dart';
import 'package:cmandili_mobile/features/orders/data/models/order.dart';
import 'package:cmandili_mobile/features/orders/data/order_repository.dart';
import 'package:cmandili_mobile/features/orders/presentation/order_tracking/order_tracking_screen.dart';
import 'package:cmandili_mobile/features/orders/providers/order_provider.dart';
import 'package:cmandili_mobile/features/promo/data/models/promo_code_response.dart';
import 'package:cmandili_mobile/features/promo/data/promo_repository.dart';
import 'package:cmandili_mobile/features/promo/providers/promo_provider.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

// ── Réponses Supabase préparées ──────────────────────────────────────────────

/// Ce que `vendors.is_open` répond pour le commerce du panier.
var _venueOpen = true;

/// Chaque requête HTTP partie vers Supabase, dans l'ordre.
final _http = <String>[];

http.Response _json(Object body, http.BaseRequest req) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: req,
    );

Future<http.Response> _supabaseReply(http.Request req) async {
  final url = Uri.decodeFull(req.url.toString());
  _http.add('${req.method} $url');
  if (url.contains('/rest/v1/vendors') && url.contains('is_open')) {
    return _json([{'is_open': _venueOpen}], req);
  }
  if (url.contains('/rest/v1/vendors') && url.contains('latitude')) {
    // Pas de coordonnées : pas de calcul d'itinéraire, frais de base.
    return _json([{'latitude': null, 'longitude': null, 'category': 'food'}], req);
  }
  return _json([], req);
}

// ── Faux dépôts ──────────────────────────────────────────────────────────────

typedef _Created = ({
  List<CartItem> items,
  DeliveryAddress deliveryAddress,
  double subtotal,
  double deliveryFee,
  double total,
  OrderType orderType,
  String? restaurantId,
  String? supermarketId,
  String? notes,
  String paymentMethod,
  double? distanceKm,
  DateTime? estimatedDeliveryTime,
});

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository({required this.orderId, required this.chargedTotal});

  final String orderId;

  /// Le total que le serveur dit avoir facturé (déclencheur de fidélité
  /// compris) : volontairement différent du prix affiché.
  final double chargedTotal;

  final created = <_Created>[];
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
    created.add((
      items: items,
      deliveryAddress: deliveryAddress,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      orderType: orderType,
      restaurantId: restaurantId,
      supermarketId: supermarketId,
      notes: notes,
      paymentMethod: paymentMethod,
      distanceKm: distanceKm,
      estimatedDeliveryTime: estimatedDeliveryTime,
    ));
    return (
      orderId: orderId,
      deliveryFee: deliveryFee,
      total: chargedTotal,
      loyaltyMilestoneType: null,
      loyaltyDiscountAmount: 0.0,
    );
  }

  @override
  Future<bool> cancelOrder(String orderId) async {
    cancelled.add(orderId);
    return true;
  }

  // L'écran de suivi s'ouvre après une commande réussie : il ne reçoit rien.
  @override
  Stream<List<Map<String, dynamic>>> streamDeliveryRows(String orderId) =>
      StreamController<List<Map<String, dynamic>>>().stream;

  @override
  Stream<List<Map<String, dynamic>>> streamDriverRows(String driverId) =>
      StreamController<List<Map<String, dynamic>>>().stream;
}

class _FakePromoRepository extends PromoRepository {
  _FakePromoRepository({this.commit});

  /// Réponse de la consommation du code (null : aucun code dans ce test).
  final PromoCodeResponse? commit;

  final previewed = <String>[];
  final applied = <String>[];
  final released = <String>[];

  @override
  Future<PromoCodeResponse> validatePromoCode({
    required String promoCode,
    required List<CartItem> items,
  }) async {
    previewed.add(promoCode);
    return const PromoCodeResponse(
        isSuccess: true, discountAmount: 4, newSubtotal: 16);
  }

  @override
  Future<PromoCodeResponse> applyPromoCode({
    required String promoCode,
    required List<CartItem> items,
  }) async {
    applied.add(promoCode);
    return commit!;
  }

  @override
  Future<void> releaseUsage({required String promoCode}) async {
    released.add(promoCode);
  }
}

/// Le vrai service (passerelle cash), sauf quand [refuse] : la passerelle
/// répond alors « refusé », comme le ferait une carte rejetée.
class _RecordingPaymentService extends PaymentService {
  _RecordingPaymentService({this.refuse = false});

  final bool refuse;
  final calls = <({String orderId, double amount, String methodKey})>[];

  @override
  Future<PaymentResult> processAndRecord({
    required String orderId,
    required double amount,
    required String methodKey,
    required BuildContext context,
  }) async {
    calls.add((orderId: orderId, amount: amount, methodKey: methodKey));
    if (refuse) return const PaymentResult(success: false);
    return super.processAndRecord(
      orderId: orderId,
      amount: amount,
      methodKey: methodKey,
      context: context,
    );
  }
}

// ── Écran et gestes ──────────────────────────────────────────────────────────

const _subtotal = 20.0;
const _estimatedFee = 3.5;

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

Finder get _placeOrderButton => find.descendant(
      of: _byTypeName('PlaceOrderBar'),
      matching: find.byType(ElevatedButton),
    );

bool _isPlacingOrder(WidgetTester tester) =>
    (tester.widget(_byTypeName('PlaceOrderBar')) as dynamic).isPlacingOrder
        as bool;

class _Checkout {
  _Checkout(this.container, this.orders, this.promos, this.payments, this.l);

  final ProviderContainer container;
  final _FakeOrderRepository orders;
  final _FakePromoRepository promos;
  final _RecordingPaymentService payments;
  final AppLocalizations l;

  List<CartItem> get cart => container.read(cartProvider);
}

Future<_Checkout> _pumpCheckout(
  WidgetTester tester, {
  required bool venueOpen,
  PromoCodeResponse? promoCommit,
  bool refusePayment = false,
  String orderId = 'o-1',
  double chargedTotal = _subtotal + _estimatedFee,
}) async {
  _venueOpen = venueOpen;
  _http.clear();
  SharedPreferences.setMockInitialValues({});
  // Large : ce sont des tests de logique, et la police de test, plus large
  // que les vraies, fait déborder l'en-tête de la liste d'adresses à 393 px.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final orders =
      _FakeOrderRepository(orderId: orderId, chargedTotal: chargedTotal);
  final promos = _FakePromoRepository(commit: promoCommit);
  final payments = _RecordingPaymentService(refuse: refusePayment);
  final container = ProviderContainer(overrides: [
    orderRepositoryProvider.overrideWithValue(orders),
    promoRepositoryProvider.overrideWithValue(promos),
    paymentServiceProvider.overrideWithValue(payments),
    // Le suivi ouvert après une commande réussie reste sur « chargement ».
    orderStreamProvider
        .overrideWith((ref, id) => StreamController<Order>().stream),
  ]);
  addTearDown(container.dispose);
  container.read(cartProvider.notifier).addItem(_line());

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CheckoutScreen(
        subtotal: _subtotal,
        deliveryFee: _estimatedFee,
        total: _subtotal + _estimatedFee,
      ),
    ),
  ));
  await tester.pump();
  final l = await AppLocalizations.delegate.load(const Locale('fr'));
  return _Checkout(container, orders, promos, payments, l);
}

Future<void> _settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Adresse choisie comme le ferait le client : l'écran de sélection s'ouvre
/// et se referme sur une adresse.
Future<void> _chooseAddress(WidgetTester tester) async {
  await tester.tap(_byTypeName('CheckoutAddressPicker'));
  await _settleFrames(tester);
  Navigator.of(tester.element(find.byType(AddressSelectionScreen)))
      .pop(_address);
  await _settleFrames(tester);
  expect(find.text(_address.fullAddress), findsWidgets);
}

Future<void> _typeContact(WidgetTester tester, AppLocalizations l) async {
  await tester.enterText(find.widgetWithText(TextField, l.fullNameHint), 'Sami');
  await tester.enterText(find.widgetWithText(TextField, l.phoneHint), '22123456');
  await tester.pump();
}

/// Aperçu du code « promo10 » : validé à blanc, rien n'est consommé.
Future<void> _previewPromo(WidgetTester tester, AppLocalizations l) async {
  final field = find.widgetWithText(TextField, l.promoCodePlaceholder);
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, 'promo10');
  final apply = find.widgetWithText(ElevatedButton, l.applyPromoCode);
  await tester.ensureVisible(apply);
  await _settleFrames(tester);
  await tester.tap(apply);
  await _settleFrames(tester);
  expect(find.widgetWithText(TextButton, l.removePromoCode), findsOneWidget,
      reason: 'l\'aperçu du code doit être affiché avant de commander');
}

Future<void> _placeOrder(WidgetTester tester) async {
  await tester.tap(_placeOrderButton);
  await tester.pump();
  await _settleFrames(tester);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
      httpClient: MockClient(_supabaseReply),
    );
  });

  // Un geste qui tombe à côté doit faire échouer le test, pas passer en
  // silence.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('commerce fermé : ni code consommé, ni commande, panier intact',
      (tester) async {
    final c = await _pumpCheckout(tester, venueOpen: false);
    await _chooseAddress(tester);
    await _typeContact(tester, c.l);
    await _previewPromo(tester, c.l);

    await _placeOrder(tester);

    expect(find.text(c.l.venueClosedNow), findsOneWidget);
    expect(_http.where((r) => r.contains('vendors') && r.contains('is_open')),
        hasLength(1));
    // Le contrôle a lieu AVANT de consommer le code et de créer la commande.
    expect(c.promos.applied, isEmpty);
    expect(c.promos.released, isEmpty);
    expect(c.orders.created, isEmpty);
    expect(c.payments.calls, isEmpty);
    expect(_http.where((r) => r.contains('latitude')), isEmpty);
    expect(c.cart, hasLength(1), reason: 'le panier n\'est jamais vidé');
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(_isPlacingOrder(tester), isFalse);
  });

  testWidgets(
      'code promo refusé au moment de le consommer : pas de commande, code '
      'retiré de l\'écran', (tester) async {
    final c = await _pumpCheckout(
      tester,
      venueOpen: true,
      promoCommit: const PromoCodeResponse(
        isSuccess: false,
        errorCode: 'ALREADY_USED',
        errorMessage: 'Vous avez déjà utilisé ce code promo',
      ),
    );
    await _chooseAddress(tester);
    await _typeContact(tester, c.l);
    await _previewPromo(tester, c.l);

    await _placeOrder(tester);

    expect(c.promos.previewed, ['promo10']);
    // Consommé sous sa forme normalisée, celle que l'aperçu a retenue.
    expect(c.promos.applied, ['PROMO10']);
    expect(find.text(c.l.promoErrorAlreadyUsed), findsOneWidget);
    // Le code est retiré : champ vidé, bouton « Appliquer » de retour.
    final field = tester.widget<TextField>(
        find.widgetWithText(TextField, c.l.promoCodePlaceholder));
    expect(field.controller!.text, isEmpty);
    expect(find.widgetWithText(ElevatedButton, c.l.applyPromoCode),
        findsOneWidget);
    expect(c.orders.created, isEmpty);
    expect(c.payments.calls, isEmpty);
    expect(c.promos.released, isEmpty, reason: 'rien n\'a été consommé');
    expect(c.cart, hasLength(1));
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(_isPlacingOrder(tester), isFalse);
  });

  testWidgets(
      'paiement refusé : la commande est annulée et le code promo est rendu',
      (tester) async {
    final c = await _pumpCheckout(
      tester,
      venueOpen: true,
      promoCommit: const PromoCodeResponse(
          isSuccess: true, discountAmount: 4, newSubtotal: 16),
      refusePayment: true,
      orderId: 'o-77',
      chargedTotal: 19,
    );
    await _chooseAddress(tester);
    await _typeContact(tester, c.l);
    await _previewPromo(tester, c.l);

    await _placeOrder(tester);

    expect(c.promos.applied, ['PROMO10']);
    // La commande part avec le sous-total du SERVEUR, jamais un calcul local.
    expect(c.orders.created, hasLength(1));
    final order = c.orders.created.single;
    expect(order.subtotal, 16);
    expect(order.deliveryFee, kDeliveryBaseFee);
    expect(order.total, 16 + kDeliveryBaseFee);
    // Le paiement porte sur le total RENVOYÉ par la création de commande.
    expect(c.payments.calls, hasLength(1));
    expect(c.payments.calls.single.orderId, 'o-77');
    expect(c.payments.calls.single.amount, 19);
    expect(c.payments.calls.single.methodKey, 'cash');
    // Refus : annulation de la commande ET restitution du code.
    expect(c.orders.cancelled, ['o-77']);
    expect(c.promos.released, ['PROMO10']);
    expect(find.text(c.l.paymentFailedOrderCancelled), findsOneWidget);
    expect(c.cart, hasLength(1), reason: 'le panier n\'est pas vidé');
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.byType(OrderTrackingScreen), findsNothing);
    expect(_isPlacingOrder(tester), isFalse);
  });

  testWidgets(
      'commande réussie : montants du serveur, paiement cash, panier vidé, '
      'suivi ouvert', (tester) async {
    final c = await _pumpCheckout(
      tester,
      venueOpen: true,
      orderId: 'o-1',
      chargedTotal: 23.5,
    );
    await _chooseAddress(tester);
    await _typeContact(tester, c.l);

    await _placeOrder(tester);

    expect(_http.where((r) => r.contains('vendors') && r.contains('is_open')),
        hasLength(1));
    expect(_http.where((r) => r.contains('vendors') && r.contains('latitude')),
        hasLength(1));
    expect(c.promos.applied, isEmpty);

    expect(c.orders.created, hasLength(1));
    final order = c.orders.created.single;
    expect(order.items, hasLength(1));
    expect(order.subtotal, _subtotal);
    // Sans coordonnées du commerce : pas de distance, frais de base.
    expect(order.distanceKm, isNull);
    expect(order.deliveryFee, kDeliveryBaseFee);
    expect(order.total, _subtotal + kDeliveryBaseFee);
    expect(order.orderType, OrderType.food);
    expect(order.restaurantId, 'v1');
    expect(order.supermarketId, isNull);
    expect(order.notes, isNull);
    expect(order.paymentMethod, 'cash');
    expect(order.estimatedDeliveryTime, isNull);
    expect(order.deliveryAddress.id, _address.id);
    expect(order.deliveryAddress.recipientName, 'Sami');
    expect(order.deliveryAddress.phone, '22123456');

    expect(c.payments.calls, hasLength(1));
    expect(c.payments.calls.single.orderId, 'o-1');
    expect(c.payments.calls.single.amount, 23.5);
    expect(c.payments.calls.single.methodKey, 'cash');
    // La vraie passerelle cash a réussi et enregistré son paiement.
    expect(_http.where((r) => r.startsWith('POST') && r.contains('payments')),
        hasLength(1));

    expect(c.orders.cancelled, isEmpty);
    expect(c.promos.released, isEmpty);
    expect(c.cart, isEmpty, reason: 'le panier est vidé après paiement');
    final tracking =
        tester.widget<OrderTrackingScreen>(find.byType(OrderTrackingScreen));
    expect(tracking.orderId, 'o-1');
    expect(tracking.justPlaced, isTrue);
  });
}
