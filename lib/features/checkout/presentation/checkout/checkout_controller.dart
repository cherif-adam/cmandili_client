import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/payment/payment_service.dart';
import '../../../../core/utils/delivery_fee.dart';
import '../../../../core/utils/location_service.dart';
import '../../../cart/data/models/cart_item.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../loyalty/data/loyalty_eligibility.dart';
import '../../../orders/data/models/order.dart';
import '../../../orders/providers/order_provider.dart';
import '../../../profile/providers/profile_repository_provider.dart';
import '../../../promo/data/models/promo_code_response.dart';
import '../../../promo/providers/promo_provider.dart';
import '../../data/checkout_repository.dart';
import '../../data/models/delivery_address.dart';

final checkoutRepositoryProvider =
    Provider<CheckoutRepository>((ref) => CheckoutRepository());

/// One controller per checkout screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces.
final checkoutControllerProvider = NotifierProvider.autoDispose
    .family<CheckoutController, CheckoutState, Object>(CheckoutController.new);

/// What the user typed in the form's text fields, untrimmed.
typedef CheckoutFields = ({String name, String phone, String notes});

/// How placing the order ended. The screen turns it into a message or a
/// navigation.
sealed class CheckoutOutcome {
  const CheckoutOutcome();
}

class CheckoutMissingAddress extends CheckoutOutcome {
  const CheckoutMissingAddress();
}

class CheckoutMissingPhone extends CheckoutOutcome {
  const CheckoutMissingPhone();
}

/// The shop closed: seen by the fresh check before anything was committed,
/// or raised by the enforce_venue_open trigger at insert time.
class CheckoutVenueClosed extends CheckoutOutcome {
  const CheckoutVenueClosed();
}

/// The promo code was refused when it was committed. The promo state has
/// been reset; nothing was created.
class CheckoutPromoRefused extends CheckoutOutcome {
  const CheckoutPromoRefused(this.response);

  final PromoCodeResponse response;
}

/// The payment was refused: the order was cancelled and a committed promo
/// usage released.
class CheckoutPaymentRefused extends CheckoutOutcome {
  const CheckoutPaymentRefused(this.message);

  /// The gateway's own message, if it gave one.
  final String? message;
}

class CheckoutPlaced extends CheckoutOutcome {
  const CheckoutPlaced({required this.orderId, required this.orderType});

  final String orderId;
  final OrderType orderType;
}

class CheckoutFailed extends CheckoutOutcome {
  const CheckoutFailed(this.error);

  final Object error;
}

@immutable
class CheckoutState {
  const CheckoutState({
    this.selectedAddress,
    this.isPlacingOrder = false,
    this.loyaltyPreview,
  });

  final DeliveryAddress? selectedAddress;
  final bool isPlacingOrder;

  // Preview only — the server's BEFORE INSERT trigger makes the real,
  // enforced determination at order creation. Null until loaded, and null
  // forever if this isn't a milestone order.
  final LoyaltyMilestonePreview? loyaltyPreview;

  CheckoutState copyWith({
    DeliveryAddress? selectedAddress,
    bool? isPlacingOrder,
    LoyaltyMilestonePreview? loyaltyPreview,
  }) {
    return CheckoutState(
      selectedAddress: selectedAddress ?? this.selectedAddress,
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      loyaltyPreview: loyaltyPreview ?? this.loyaltyPreview,
    );
  }
}

/// The totals shown before the order exists.
///
/// The displayed totals use [deliveryFee] as an estimate (the final fee is
/// recomputed from coordinates at placement time). Loyalty preview: an
/// estimate shown before the order exists. The server may compute a
/// different discount if this preview raced with another order —
/// [CheckoutController.placeOrder] always uses the actual returned values,
/// never this estimate, for what's charged/paid.
({double effectiveSubtotal, double loyaltyDiscount, double estimatedTotal})
    checkoutPreviewTotals({
  required double subtotal,
  required double deliveryFee,
  required PromoState promoState,
  required LoyaltyMilestonePreview? loyaltyPreview,
}) {
  final effectiveSubtotal = promoState.isApplied
      ? (promoState.response!.newSubtotal ?? subtotal)
      : subtotal;
  final loyaltyDiscountPreview = loyaltyPreview == null
      ? 0.0
      : deliveryFee * loyaltyPreview.discountMultiplier;
  final previewDeliveryFee = deliveryFee - loyaltyDiscountPreview;
  final estimatedTotal = effectiveSubtotal + previewDeliveryFee;
  return (
    effectiveSubtotal: effectiveSubtotal,
    loyaltyDiscount: loyaltyDiscountPreview,
    estimatedTotal: estimatedTotal,
  );
}

/// Everything the checkout screen does besides drawing itself: the chosen
/// address, the promo preview, and placing the order (venue check, promo
/// commit, delivery fee, order creation, payment, and the undo steps when
/// something fails).
class CheckoutController
    extends AutoDisposeFamilyNotifier<CheckoutState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  /// Cash on delivery is the only method offered.
  static const selectedPaymentMethod = 'cash';

  bool _disposed = false;

  @override
  CheckoutState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    _loadLoyaltyPreview();
    return const CheckoutState();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadLoyaltyPreview() async {
    final preview = await predictNextOrderMilestone();
    if (!_disposed) state = state.copyWith(loyaltyPreview: preview);
  }

  /// The name and phone saved on the profile, to pre-fill the contact card.
  Future<({String? fullName, String? phone})?> loadContact() =>
      ref.read(profileRepositoryProvider).getContact();

  // ── User actions ──────────────────────────────────────────────────────────

  void selectAddress(DeliveryAddress address) =>
      state = state.copyWith(selectedAddress: address);

  /// Dry-run of [code] against the current cart: shows the discount without
  /// consuming the code.
  void previewPromo(String code) {
    if (code.isNotEmpty) {
      ref.read(promoProvider.notifier).validate(code, ref.read(cartProvider));
    }
  }

  void removePromo() => ref.read(promoProvider.notifier).reset();

  /// Re-prices delivery from the coordinates, creates the order and pays it.
  ///
  /// Once started, placing the order goes to the end or is undone, whether
  /// the screen is still open or not: never a promo usage consumed for no
  /// order, an order left unpaid, or a refused payment left uncancelled.
  /// So everything it needs is read here, when Commander is tapped — the
  /// address, the [fields], the cart, the promo, the repositories — and
  /// nothing goes through `ref` once the first network call is under way
  /// (this controller is disposed a frame after its screen).
  ///
  /// [context] is the screen's. It is only asked whether the screen is still
  /// open: to reset the promo field, and to hand the payment service a
  /// context for a gateway that shows its own UI. Once the screen is gone the
  /// payment gets none: cash does not need one, and a gateway that does must
  /// refuse, which cancels the order and releases the promo like any refusal.
  Future<CheckoutOutcome> placeOrder({
    required BuildContext context,
    required double subtotal,
    required CheckoutFields fields,
  }) async {
    // ── Address validation ───────────────────────────────────────────────
    final address = state.selectedAddress;
    if (address == null) return const CheckoutMissingAddress();

    final phone = fields.phone.trim();
    if (phone.isEmpty) return const CheckoutMissingPhone();

    // Everything below works without the screen: read it all now.
    final checkoutRepo = ref.read(checkoutRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final promoRepo = ref.read(promoRepositoryProvider);
    final orderRepo = ref.read(orderRepositoryProvider);
    final paymentService = ref.read(paymentServiceProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final promoNotifier = ref.read(promoProvider.notifier);
    // The cart being ordered: the same lines for the venue check, the promo
    // commit, the delivery fee and the order itself.
    final cartItems = ref.read(cartProvider);

    state = state.copyWith(isPlacingOrder: true);

    // Read once, before the try, so the catch block can also see it —
    // needed to release a committed promo usage on any failure below.
    final promoState = ref.read(promoProvider);
    // True only once applyPromoCode has actually committed the usage —
    // distinct from promoState.isApplied, which is also true on the
    // early-return invalid/expired path (nothing to release there).
    // Everything that can fail after the commit (order creation, payment)
    // must release it on failure or the customer permanently loses the
    // promo usage with no order to show for it.
    var promoCommitted = false;

    try {
      // ── P0 ghost-order guard ───────────────────────────────────────────
      // Fresh check that the venue is still open BEFORE committing the promo
      // or inserting the order (so we never consume a promo then abort, and
      // never silently clear the user's cart). The enforce_venue_open DB
      // trigger is the authoritative backstop if the venue closes in the race.
      if (!await _venueStillOpen(checkoutRepo, cartItems)) {
        return const CheckoutVenueClosed(); // `finally` resets isPlacingOrder; cart is left untouched.
      }

      // ── Promo commit ───────────────────────────────────────────────────
      // If the user previewed a promo code (dry-run was successful), we now
      // call apply_promo_code with p_dry_run = FALSE to commit the usage and
      // get the authoritative server-computed effective subtotal.
      //
      // SECURITY: the frontend NEVER computes the discounted price.
      // The server-returned new_subtotal is used as-is.
      double effectiveSubtotal = subtotal;

      if (promoState.isApplied) {
        // Les LIGNES du panier, jamais un montant : le serveur relit les prix
        // lui-même (migration 20260929100000). Ce sont celles qui seront
        // commandées : le panier réellement commandé sert de base.
        final applyResult = await promoRepo.applyPromoCode(
          promoCode: promoState.appliedCode,
          items: cartItems,
        );

        if (!applyResult.isSuccess) {
          // The code was consumed or expired between preview and placement.
          // Reset the promo UI (gone with its screen if it was closed); the
          // screen surfaces the server's error.
          if (context.mounted) promoNotifier.reset();
          if (!_disposed) state = state.copyWith(isPlacingOrder: false);
          return CheckoutPromoRefused(applyResult); // Abort — let the user correct and re-submit.
        }

        // Use the server-authorised discounted subtotal.
        effectiveSubtotal = applyResult.newSubtotal ?? subtotal;
        promoCommitted = true;
      }

      // ── Delivery fee computation ───────────────────────────────────────
      final firstItem = cartItems.isNotEmpty ? cartItems.first : null;
      final supermarketId = firstItem?.groceryItem?.supermarketId;
      // `orders.restaurant_id` is a plain FK to what is now the generic
      // `vendors` table, so a florist/pet/gift/bakery order rides the same
      // column. Leaving it null (as it was before the generic categories)
      // would orphan the order from its shop: the partner app looks its
      // orders up by this id, and the driver resolves the pickup pin from it.
      final restaurantId = firstItem?.foodItem?.restaurantId ??
          firstItem?.vendorItem?.vendorId;

      double? pickupLat;
      double? pickupLng;
      String? shopCategory;

      // Fetch pickup coordinates only — delivery_fee is no longer taken from
      // the partner row; the platform fee algorithm uses a fixed base instead.
      // One lookup for every category — see the note in _venueStillOpen.
      // Without the vendorItem fallback a flower or pet-supply order would
      // carry no pickup coordinates, and the distance-based delivery fee
      // would be computed from nothing.
      try {
        final vendorId = restaurantId ??
            supermarketId ??
            cartItems.first.vendorItem?.vendorId;
        if (vendorId != null) {
          final row = await checkoutRepo.vendorPickupRow(vendorId);
          if (row != null) {
            pickupLat = (row['latitude'] as num?)?.toDouble();
            pickupLng = (row['longitude'] as num?)?.toDouble();
            // Lue dans la requête qui cherchait déjà les coordonnées : la
            // catégorie ne vaut pas un aller-retour réseau de plus.
            shopCategory = row['category']?.toString();
          }
        }
      } catch (_) {}

      final distanceKm = await tryDistanceKm(
        originLat: pickupLat,
        originLng: pickupLng,
        destLat: address.latitude,
        destLng: address.longitude,
      );
      // `order_type` porte désormais la CATÉGORIE du commerce, pas une
      // déduction à partir du type de ligne. Une commande de fleurs, de
      // cadeaux ou d'électronique s'enregistrait sinon comme une commande de
      // restaurant. Repli sur l'ancienne déduction si la boutique n'a pas pu
      // être lue : une ligne d'épicerie ne vient que d'un supermarché.
      final orderType = shopCategory != null
          ? orderTypeForCategory(shopCategory)
          : (supermarketId != null ? OrderType.grocery : OrderType.food);

      // Commerce : base 3.500 DT + 0.500 DT/km au-delà de 3 km.
      // Supermarché : forfait 5 DT -- le livreur fait les courses en rayon,
      // le coût est par course et non par kilomètre.
      //
      // Le même test que l'aperçu du panier, délibérément : c'est ce qui
      // garantit que le client paie les frais qu'on lui a montrés.
      final isFlatRate = cartIsFlatRateDelivery(cartItems);
      final finalDeliveryFee = calculateDeliveryFee(
        distanceKm: distanceKm,
        partnerFlatFee: isFlatRate ? kFlatDeliveryFee : kDeliveryBaseFee,
        isFlatRate: isFlatRate,
      );

      // Best-effort ETA — reuses the same pickup/destination pair as the
      // delivery-fee distance call above, just keeping the duration that
      // call already receives from Mapbox and discards. Null (no estimate
      // shown) on any failure — this is a display nicety, never worth
      // blocking or retrying checkout over.
      DateTime? estimatedDeliveryTime;
      if (pickupLat != null && pickupLng != null &&
          !(pickupLat == 0 && pickupLng == 0)) {
        final durationSeconds = await LocationService.estimateRouteDurationSeconds(
          pickupLat, pickupLng,
          address.latitude, address.longitude,
        );
        if (durationSeconds != null) {
          estimatedDeliveryTime =
              DateTime.now().add(Duration(seconds: durationSeconds));
        }
      }

      // effectiveSubtotal already has the promo discount baked in (or equals
      // the screen's subtotal when no promo was applied).
      final finalTotal = effectiveSubtotal + finalDeliveryFee;

      final addressWithContact = address.copyWith(
        recipientName: fields.name.trim().isEmpty ? null : fields.name.trim(),
        phone: phone,
      );

      // Persist contact back to profile (fire-and-forget).
      profileRepo
          .saveContact(
            phone: phone,
            fullName: fields.name.trim().isNotEmpty ? fields.name.trim() : null,
          )
          .then((_) {}, onError: (_) {});

      // ── Create order ───────────────────────────────────────────────────
      // finalDeliveryFee/finalTotal above are the STICKER price sent to the
      // server; apply_loyalty_at_checkout() (BEFORE INSERT trigger) may
      // overwrite delivery_fee/total on a 5th/10th order before the row is
      // persisted. The returned record reflects what was actually charged —
      // used below for payment instead of the sticker finalTotal, so a
      // loyalty order is never paid/recorded at the pre-discount amount.
      final createdOrder = await orderRepo.createOrder(
            items: cartItems,
            deliveryAddress: addressWithContact,
            subtotal: effectiveSubtotal, // server-authorised value
            deliveryFee: finalDeliveryFee,
            total: finalTotal,
            orderType: orderType,
            restaurantId: restaurantId,
            supermarketId: supermarketId,
            notes: fields.notes.isNotEmpty ? fields.notes : null,
            paymentMethod: selectedPaymentMethod,
            distanceKm: distanceKm,
            estimatedDeliveryTime: estimatedDeliveryTime,
          );
      final orderId = createdOrder.orderId;

      // ── Payment ────────────────────────────────────────────────────────
      final paymentResult = await paymentService.processAndRecord(
        orderId: orderId,
        amount: createdOrder.total,
        methodKey: selectedPaymentMethod,
        context: context.mounted ? context : null,
      );

      if (!paymentResult.success) {
        await orderRepo.cancelOrder(orderId);
        if (promoCommitted) {
          await promoRepo.releaseUsage(promoCode: promoState.appliedCode);
        }
        return CheckoutPaymentRefused(paymentResult.errorMessage);
      }

      // Order stays 'pending' — the partner must accept it before it moves
      // to 'confirmed'. Do NOT call confirmOrder() here.
      cartNotifier.clearCart();

      return CheckoutPlaced(orderId: orderId, orderType: orderType);
    } catch (e) {
      // Release before the screen shows anything — this is a plain network
      // call with no context/widget dependency, made whether the screen is
      // still open or not: skipping it would leave the promo usage
      // permanently burned for no order.
      if (promoCommitted) {
        await promoRepo.releaseUsage(promoCode: promoState.appliedCode);
      }
      // The enforce_venue_open DB trigger raises 'VENUE_CLOSED' if the venue
      // closed in the race between our re-check and the insert. Map it to the
      // friendly message instead of surfacing a raw error string.
      return e.toString().contains('VENUE_CLOSED')
          ? const CheckoutVenueClosed()
          : CheckoutFailed(e);
    } finally {
      if (!_disposed) state = state.copyWith(isPlacingOrder: false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Fresh server check that the cart's venue is still open, moments before we
  /// place the order — defends against the venue closing (or the auto-close
  /// cron firing) while the user lingered in the cart. Colis/facture never
  /// reach this screen. Returns true when ordering may proceed; on a network
  /// error it returns true and lets the `enforce_venue_open` DB trigger be the
  /// authoritative backstop.
  Future<bool> _venueStillOpen(
      CheckoutRepository checkoutRepo, List<CartItem> cartItems) async {
    if (cartItems.isEmpty) return true;
    final first = cartItems.first;
    // Every shop — restaurant, supermarket, florist, pet shop — is a row in
    // `vendors`, so one lookup covers all of them. Reading the legacy views
    // instead would return nothing for the newer categories and wrongly
    // report a closed shop as open.
    final vendorId = first.foodItem?.restaurantId ??
        first.groceryItem?.supermarketId ??
        first.vendorItem?.vendorId;
    if (vendorId == null) return true;
    try {
      return (await checkoutRepo.vendorIsOpen(vendorId)) ?? true;
    } catch (_) {
      return true; // DB trigger is the authoritative guard
    }
  }
}
