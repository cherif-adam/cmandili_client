import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/delivery_fee.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/payment/payment_service.dart';
import '../data/models/delivery_address.dart';
import 'address_selection_screen.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import '../../orders/presentation/order_success/order_success_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/data/models/order.dart';
import '../../orders/providers/order_provider.dart';
import '../../promo/presentation/promo_error_text.dart';
import '../../promo/providers/promo_provider.dart';
import '../../loyalty/data/loyalty_eligibility.dart';
import '../../profile/data/profile_repository.dart';
import 'widgets/checkout_address_picker.dart';
import 'widgets/checkout_section_title.dart';
import 'widgets/order_notes_field.dart';
import 'widgets/place_order_bar.dart';
import 'widgets/checkout_contact_card.dart';
import 'widgets/promo_code_field.dart';
import 'widgets/order_summary_card.dart';
import 'widgets/payment_option_tile.dart';

/// "Commande", top to bottom: delivery address, contact, payment method,
/// notes, promo code, order summary — then the PlaceOrderBar.
///
/// _placeOrder() below does the work: re-prices delivery from the
/// coordinates, creates the order, then opens the success / tracking
/// screen.
class CheckoutScreen extends ConsumerStatefulWidget {
  final double subtotal;
  final double deliveryFee;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  DeliveryAddress? _selectedAddress;
  final _notesController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _promoCodeController = TextEditingController();
  bool _isPlacingOrder = false;
  final String _selectedPaymentMethod = 'cash';

  // Preview only — the server's BEFORE INSERT trigger makes the real,
  // enforced determination at order creation. Null until loaded, and null
  // forever if this isn't a milestone order.
  LoyaltyMilestonePreview? _loyaltyPreview;

  final _profileRepo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _prefillContactFromProfile();
    _loadLoyaltyPreview();
  }

  Future<void> _loadLoyaltyPreview() async {
    final preview = await predictNextOrderMilestone();
    if (mounted) setState(() => _loyaltyPreview = preview);
  }

  Future<void> _prefillContactFromProfile() async {
    try {
      final contact = await _profileRepo.getContact();
      if (!mounted || contact == null) return;
      setState(() {
        if (_nameController.text.isEmpty) {
          _nameController.text = contact.fullName ?? '';
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = contact.phone ?? '';
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _notesController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _selectAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (context) => const AddressSelectionScreen()),
    );
    if (address != null) {
      setState(() => _selectedAddress = address);
    }
  }

  // ── Order placement ────────────────────────────────────────────────────────

  /// Fresh server check that the cart's venue is still open, moments before we
  /// place the order — defends against the venue closing (or the auto-close
  /// cron firing) while the user lingered in the cart. Colis/facture never
  /// reach this screen. Returns true when ordering may proceed; on a network
  /// error it returns true and lets the `enforce_venue_open` DB trigger be the
  /// authoritative backstop.
  Future<bool> _venueStillOpen() async {
    final cartItems = ref.read(cartProvider);
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
      final row = await Supabase.instance.client
          .from('vendors')
          .select('is_open')
          .eq('id', vendorId)
          .maybeSingle();
      return (row?['is_open'] as bool?) ?? true;
    } catch (_) {
      return true; // DB trigger is the authoritative guard
    }
  }

  Future<void> _placeOrder() async {
    // ── Address validation ───────────────────────────────────────────────
    if (_selectedAddress == null) {
      _showSnack(AppLocalizations.of(context)!.pleaseSelectAddress);
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnack(AppLocalizations.of(context)!.pleaseEnterPhone);
      return;
    }

    setState(() => _isPlacingOrder = true);

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
      if (!await _venueStillOpen()) {
        if (!mounted) return;
        _showSnack(AppLocalizations.of(context)!.venueClosedNow);
        return; // `finally` resets _isPlacingOrder; cart is left untouched.
      }

      // ── Promo commit ───────────────────────────────────────────────────
      // If the user previewed a promo code (dry-run was successful), we now
      // call apply_promo_code with p_dry_run = FALSE to commit the usage and
      // get the authoritative server-computed effective subtotal.
      //
      // SECURITY: the frontend NEVER computes the discounted price.
      // The server-returned new_subtotal is used as-is.
      double effectiveSubtotal = widget.subtotal;

      if (promoState.isApplied) {
        // Les LIGNES du panier, jamais un montant : le serveur relit les prix
        // lui-même (migration 20260929100000). Lues ici, juste avant l'appel,
        // pour que ce soit le panier réellement commandé qui serve de base.
        final promoItems = ref.read(cartProvider);
        final applyResult = await ref
            .read(promoRepositoryProvider)
            .applyPromoCode(
              promoCode: promoState.appliedCode,
              items: promoItems,
            );

        if (!mounted) return;

        if (!applyResult.isSuccess) {
          // The code was consumed or expired between preview and placement.
          // Reset the promo UI and surface the server's error message.
          ref.read(promoProvider.notifier).reset();
          _promoCodeController.clear();
          _showSnack(
            promoErrorText(AppLocalizations.of(context)!, applyResult),
          );
          setState(() => _isPlacingOrder = false);
          return; // Abort — let the user correct and re-submit.
        }

        // Use the server-authorised discounted subtotal.
        effectiveSubtotal = applyResult.newSubtotal ?? widget.subtotal;
        promoCommitted = true;
      }

      // ── Delivery fee computation ───────────────────────────────────────
      final cartItems = ref.read(cartProvider);
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
      // One lookup for every category — see the note in _isVenueOpen. Without
      // the vendorItem fallback a flower or pet-supply order would carry no
      // pickup coordinates, and the distance-based delivery fee would be
      // computed from nothing.
      try {
        final vendorId = restaurantId ??
            supermarketId ??
            cartItems.first.vendorItem?.vendorId;
        if (vendorId != null) {
          final row = await Supabase.instance.client
              .from('vendors')
              .select('latitude, longitude, category')
              .eq('id', vendorId)
              .maybeSingle();
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
        destLat: _selectedAddress!.latitude,
        destLng: _selectedAddress!.longitude,
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
          _selectedAddress!.latitude, _selectedAddress!.longitude,
        );
        if (durationSeconds != null) {
          estimatedDeliveryTime =
              DateTime.now().add(Duration(seconds: durationSeconds));
        }
      }

      // effectiveSubtotal already has the promo discount baked in (or equals
      // widget.subtotal when no promo was applied).
      final finalTotal = effectiveSubtotal + finalDeliveryFee;

      final addressWithContact = _selectedAddress!.copyWith(
        recipientName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        phone: phone,
      );

      // Persist contact back to profile (fire-and-forget).
      _profileRepo
          .saveContact(
            phone: phone,
            fullName: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : null,
          )
          .then((_) {}, onError: (_) {});

      // ── Create order ───────────────────────────────────────────────────
      // finalDeliveryFee/finalTotal above are the STICKER price sent to the
      // server; apply_loyalty_at_checkout() (BEFORE INSERT trigger) may
      // overwrite delivery_fee/total on a 5th/10th order before the row is
      // persisted. The returned record reflects what was actually charged —
      // used below for payment instead of the sticker finalTotal, so a
      // loyalty order is never paid/recorded at the pre-discount amount.
      final createdOrder = await ref.read(orderRepositoryProvider).createOrder(
            items: cartItems,
            deliveryAddress: addressWithContact,
            subtotal: effectiveSubtotal, // server-authorised value
            deliveryFee: finalDeliveryFee,
            total: finalTotal,
            orderType: orderType,
            restaurantId: restaurantId,
            supermarketId: supermarketId,
            notes: _notesController.text.isNotEmpty
                ? _notesController.text
                : null,
            paymentMethod: _selectedPaymentMethod,
            distanceKm: distanceKm,
            estimatedDeliveryTime: estimatedDeliveryTime,
          );
      final orderId = createdOrder.orderId;

      if (!mounted) return;

      // ── Payment ────────────────────────────────────────────────────────
      final paymentResult = await PaymentService().processAndRecord(
        orderId: orderId,
        amount: createdOrder.total,
        methodKey: _selectedPaymentMethod,
        context: context,
      );

      if (!mounted) return;

      if (!paymentResult.success) {
        await ref.read(orderRepositoryProvider).cancelOrder(orderId);
        if (promoCommitted) {
          await ref
              .read(promoRepositoryProvider)
              .releaseUsage(promoCode: promoState.appliedCode);
        }
        if (!mounted) return;
        _showSnack(paymentResult.errorMessage ??
            AppLocalizations.of(context)!.paymentFailedOrderCancelled);
        return;
      }

      // Order stays 'pending' — the partner must accept it before it moves
      // to 'confirmed'. Do NOT call confirmOrder() here.
      ref.read(cartProvider.notifier).clearCart();

      // Supermarket (and boutique, which shares order_type 'supermarket')
      // orders get the success hand-off screen; food orders keep the
      // existing straight-to-tracking behavior unchanged.
      if (orderType == OrderType.supermarket) {
        final l10n = AppLocalizations.of(context)!;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              orderId: orderId,
              imageAsset: 'assets/images/amana_supermarket_hero.jpg',
              title: l10n.supermarketSuccessTitle,
              trackButtonLabel: l10n.trackMyOrder,
            ),
          ),
          (route) => route.isFirst,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(orderId: orderId, justPlaced: true),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      // Release before the mounted check below — this is a plain network
      // call with no context/widget dependency, and skipping it on unmount
      // would leave the promo usage permanently burned for no order.
      if (promoCommitted) {
        await ref
            .read(promoRepositoryProvider)
            .releaseUsage(promoCode: promoState.appliedCode);
      }
      if (!mounted) return;
      // The enforce_venue_open DB trigger raises 'VENUE_CLOSED' if the venue
      // closed in the race between our re-check and the insert. Map it to the
      // friendly message instead of surfacing a raw error string.
      _showSnack(
        e.toString().contains('VENUE_CLOSED')
            ? AppLocalizations.of(context)!.venueClosedNow
            : AppLocalizations.of(context)!.genericErrorWith(e.toString()),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final promoState = ref.watch(promoProvider);

    // The displayed totals use widget.deliveryFee as an estimate (the final
    // fee is recomputed from coordinates at placement time).
    final effectiveSubtotal = promoState.isApplied
        ? (promoState.response!.newSubtotal ?? widget.subtotal)
        : widget.subtotal;
    // Loyalty preview: an estimate shown before the order exists. The
    // server may compute a different discount if this preview raced with
    // another order — _placeOrder() always uses the actual returned values,
    // never this estimate, for what's charged/paid.
    final loyaltyDiscountPreview = _loyaltyPreview == null
        ? 0.0
        : widget.deliveryFee * _loyaltyPreview!.discountMultiplier;
    final previewDeliveryFee = widget.deliveryFee - loyaltyDiscountPreview;
    final estimatedTotal = effectiveSubtotal + previewDeliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.checkout,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Scrollable form ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Delivery Address ───────────────────────────────────
                  CheckoutSectionTitle(AppLocalizations.of(context)!.deliveryAddress),
                  const SizedBox(height: 16),
                  CheckoutAddressPicker(
                    selectedAddress: _selectedAddress,
                    onTap: _selectAddress,
                  ),

                  const SizedBox(height: 32),

                  // ── Contact info ───────────────────────────────────────
                  CheckoutSectionTitle(AppLocalizations.of(context)!.contactInfo),
                  const SizedBox(height: 16),
                  CheckoutContactCard(
                    nameController: _nameController,
                    phoneController: _phoneController,
                  ),

                  const SizedBox(height: 32),

                  // ── Payment Method ─────────────────────────────────────
                  CheckoutSectionTitle(AppLocalizations.of(context)!.paymentMethod),
                  const SizedBox(height: 16),
                  PaymentOptionTile(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.success,
                    title: AppLocalizations.of(context)!.cashOnDelivery,
                    subtitle: AppLocalizations.of(context)!.payWhenYouReceive,
                    methodKey: 'cash',
                    selectedMethod: _selectedPaymentMethod,
                    onTap: () {},
                  ),

                  const SizedBox(height: 32),

                  // ── Order Notes ────────────────────────────────────────
                  CheckoutSectionTitle(AppLocalizations.of(context)!.orderNotes),
                  const SizedBox(height: 16),
                  OrderNotesField(controller: _notesController),

                  const SizedBox(height: 32),

                  // ── Promo Code ─────────────────────────────────────────
                  CheckoutSectionTitle(AppLocalizations.of(context)!.promoCode),
                  const SizedBox(height: 16),
                  PromoCodeField(
                    controller: _promoCodeController,
                    promoState: promoState,
                    onApply: () {
                      final code = _promoCodeController.text.trim();
                      if (code.isNotEmpty) {
                        ref.read(promoProvider.notifier).validate(
                              code,
                              ref.read(cartProvider),
                            );
                      }
                    },
                    onRemove: () {
                      _promoCodeController.clear();
                      ref.read(promoProvider.notifier).reset();
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── Order Summary ──────────────────────────────────────
                  CheckoutSectionTitle(AppLocalizations.of(context)!.orderSummary),
                  const SizedBox(height: 16),
                  OrderSummaryCard(
                    subtotal: widget.subtotal,
                    deliveryFee: widget.deliveryFee,
                    estimatedTotal: estimatedTotal,
                    promoState: promoState,
                    loyaltyPreview: _loyaltyPreview,
                    loyaltyDiscountAmount: loyaltyDiscountPreview,
                  ),
                ],
              ),
            ),
          ),

          PlaceOrderBar(
            isPlacingOrder: _isPlacingOrder,
            estimatedTotal: estimatedTotal,
            onPressed: _placeOrder,
          ),
        ],
      ),
    );
  }
}

// ── Extracted sub-widgets ──────────────────────────────────────────────────────
