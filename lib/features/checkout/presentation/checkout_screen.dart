import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/delivery_fee.dart';
import '../../../core/payment/payment_service.dart';
import '../data/models/delivery_address.dart';
import 'address_selection_screen.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/data/models/order.dart';
import '../../orders/providers/order_provider.dart';
import '../../promo/providers/promo_provider.dart';
import '../../promo/data/promo_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _prefillContactFromProfile();
  }

  Future<void> _prefillContactFromProfile() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await supabase
          .from('profiles')
          .select('full_name, phone')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        if (_nameController.text.isEmpty) {
          _nameController.text = (row['full_name'] as String?) ?? '';
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = (row['phone'] as String?) ?? '';
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

    try {
      // ── Promo commit ───────────────────────────────────────────────────
      // If the user previewed a promo code (dry-run was successful), we now
      // call apply_promo_code with p_dry_run = FALSE to commit the usage and
      // get the authoritative server-computed effective subtotal.
      //
      // SECURITY: the frontend NEVER computes the discounted price.
      // The server-returned new_subtotal is used as-is.
      final promoState = ref.read(promoProvider);
      double effectiveSubtotal = widget.subtotal;

      if (promoState.isApplied) {
        final applyResult = await ref
            .read(promoRepositoryProvider)
            .applyPromoCode(
              promoCode: promoState.appliedCode,
              subtotal: widget.subtotal,
            );

        if (!mounted) return;

        if (!applyResult.isSuccess) {
          // The code was consumed or expired between preview and placement.
          // Reset the promo UI and surface the server's error message.
          ref.read(promoProvider.notifier).reset();
          _promoCodeController.clear();
          _showSnack(
            applyResult.errorMessage ??
                'Code promo invalide. Veuillez réessayer.',
          );
          setState(() => _isPlacingOrder = false);
          return; // Abort — let the user correct and re-submit.
        }

        // Use the server-authorised discounted subtotal.
        effectiveSubtotal = applyResult.newSubtotal ?? widget.subtotal;
      }

      // ── Delivery fee computation ───────────────────────────────────────
      final cartItems = ref.read(cartProvider);
      final firstItem = cartItems.isNotEmpty ? cartItems.first : null;
      final restaurantId = firstItem?.foodItem?.restaurantId;
      final supermarketId = firstItem?.groceryItem?.supermarketId;
      final orderType =
          supermarketId != null ? OrderType.supermarket : OrderType.food;

      double? pickupLat;
      double? pickupLng;

      // Fetch pickup coordinates only — delivery_fee is no longer taken from
      // the partner row; the platform fee algorithm uses a fixed base instead.
      try {
        if (restaurantId != null) {
          final r = await Supabase.instance.client
              .from('restaurants')
              .select('latitude, longitude')
              .eq('id', restaurantId)
              .maybeSingle();
          if (r != null) {
            pickupLat = (r['latitude'] as num?)?.toDouble();
            pickupLng = (r['longitude'] as num?)?.toDouble();
          }
        } else if (supermarketId != null) {
          final s = await Supabase.instance.client
              .from('supermarkets')
              .select('latitude, longitude')
              .eq('id', supermarketId)
              .maybeSingle();
          if (s != null) {
            pickupLat = (s['latitude'] as num?)?.toDouble();
            pickupLng = (s['longitude'] as num?)?.toDouble();
          }
        }
      } catch (_) {}

      final distanceKm = await tryDistanceKm(
        originLat: pickupLat,
        originLng: pickupLng,
        destLat: _selectedAddress!.latitude,
        destLng: _selectedAddress!.longitude,
      );
      // Base 3.500 TND + 0.500 TND/km beyond 3 km.
      final finalDeliveryFee = calculateDeliveryFee(distanceKm: distanceKm);

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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        Supabase.instance.client.from('profiles').update({
          'phone': phone,
          if (_nameController.text.trim().isNotEmpty)
            'full_name': _nameController.text.trim(),
        }).eq('id', userId).then((_) {}, onError: (_) {});
      }

      // ── Create order ───────────────────────────────────────────────────
      final orderId = await ref.read(orderRepositoryProvider).createOrder(
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
          );

      if (!mounted) return;

      // ── Payment ────────────────────────────────────────────────────────
      final paymentResult = await PaymentService().processAndRecord(
        orderId: orderId,
        amount: finalTotal,
        methodKey: _selectedPaymentMethod,
        context: context,
      );

      if (!mounted) return;

      if (!paymentResult.success) {
        await ref.read(orderRepositoryProvider).cancelOrder(orderId);
        _showSnack(paymentResult.errorMessage ?? 'Payment failed. Order cancelled.');
        return;
      }

      // Order stays 'pending' — the partner must accept it before it moves
      // to 'confirmed'. Do NOT call confirmOrder() here.
      ref.read(cartProvider.notifier).clearCart();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(orderId: orderId),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
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
    final estimatedTotal = effectiveSubtotal + widget.deliveryFee;

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
                  Text(
                    AppLocalizations.of(context)!.deliveryAddress,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AddressPicker(
                    selectedAddress: _selectedAddress,
                    onTap: _selectAddress,
                  ),

                  const SizedBox(height: 32),

                  // ── Contact info ───────────────────────────────────────
                  Text(
                    AppLocalizations.of(context)!.contactInfo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ContactCard(
                    nameController: _nameController,
                    phoneController: _phoneController,
                  ),

                  const SizedBox(height: 32),

                  // ── Payment Method ─────────────────────────────────────
                  Text(
                    AppLocalizations.of(context)!.paymentMethod,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PaymentOption(
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
                  Text(
                    AppLocalizations.of(context)!.orderNotes,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!
                            .specialDeliveryInstructions,
                        hintStyle: TextStyle(
                            color: AppColors.textLight.withOpacity(0.5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Promo Code ─────────────────────────────────────────
                  Text(
                    AppLocalizations.of(context)!.promoCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PromoCodeField(
                    controller: _promoCodeController,
                    promoState: promoState,
                    onApply: () {
                      final code = _promoCodeController.text.trim();
                      if (code.isNotEmpty) {
                        ref.read(promoProvider.notifier).validate(
                              code,
                              widget.subtotal,
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
                  Text(
                    AppLocalizations.of(context)!.orderSummary,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OrderSummaryCard(
                    subtotal: widget.subtotal,
                    deliveryFee: widget.deliveryFee,
                    estimatedTotal: estimatedTotal,
                    promoState: promoState,
                  ),
                ],
              ),
            ),
          ),

          // ── Place Order button ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isPlacingOrder ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isPlacingOrder
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Place Order — ${CurrencyFormatter.formatPrice(estimatedTotal)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Extracted sub-widgets ──────────────────────────────────────────────────────

class _AddressPicker extends StatelessWidget {
  final DeliveryAddress? selectedAddress;
  final VoidCallback onTap;

  const _AddressPicker({required this.selectedAddress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: selectedAddress != null
                ? AppColors.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: selectedAddress == null
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_location_alt_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.selectDeliveryAddress,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAddress!.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedAddress!.fullAddress,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, color: AppColors.primary),
                ],
              ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _ContactCard({
    required this.nameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.fullNameHint,
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.textLight),
              border: InputBorder.none,
            ),
          ),
          const Divider(height: 1),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
            ],
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.phoneHint,
              prefixIcon:
                  const Icon(Icons.phone_outlined, color: AppColors.textLight),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Promo code input with Apply / Remove button and an inline feedback badge.
///
/// Layout:
///   ┌─────────────────────────────┬──────────────┐
///   │  🏷  Enter promo code…      │  [Apply]     │
///   ├─────────────────────────────┴──────────────┤
///   │  ✓ −5.000 DT de réduction appliquée!       │  ← success badge
///   │  ✗ Ce code a expiré                        │  ← error badge
///   └────────────────────────────────────────────┘
class _PromoCodeField extends StatelessWidget {
  final TextEditingController controller;
  final PromoState promoState;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  const _PromoCodeField({
    required this.controller,
    required this.promoState,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = promoState.status == PromoStatus.loading;
    final isApplied = promoState.isApplied;
    final isError = promoState.status == PromoStatus.error;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApplied
              ? AppColors.success
              : isError
                  ? AppColors.error
                  : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Input row ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isApplied,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: isApplied
                        ? AppColors.success
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context)!.promoCodePlaceholder,
                    prefixIcon: Icon(
                      Icons.discount_outlined,
                      color: isApplied ? AppColors.success : AppColors.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!isApplied) onApply();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: isApplied
                    // ── Remove button ──────────────────────────────────
                    ? TextButton(
                        onPressed: onRemove,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.removePromoCode,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      )
                    // ── Apply button ───────────────────────────────────
                    : ElevatedButton(
                        onPressed: isLoading ? null : onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                AppLocalizations.of(context)!.applyPromoCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
              ),
            ],
          ),

          // ── Feedback badge ─────────────────────────────────────────────
          if (isApplied)
            _PromoBadge(
              isSuccess: true,
              message:
                  '− ${CurrencyFormatter.formatPrice(promoState.discountAmount)} '
                  '${AppLocalizations.of(context)!.promoApplied}',
            )
          else if (isError)
            _PromoBadge(
              isSuccess: false,
              message: promoState.response?.errorMessage ?? 'Code invalide',
            ),
        ],
      ),
    );
  }
}

class _PromoBadge extends StatelessWidget {
  final bool isSuccess;
  final String message;

  const _PromoBadge({required this.isSuccess, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Order summary card that conditionally shows the discount line item.
class _OrderSummaryCard extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double estimatedTotal;
  final PromoState promoState;

  const _OrderSummaryCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.estimatedTotal,
    required this.promoState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: AppLocalizations.of(context)!.subtotal,
            value: CurrencyFormatter.formatPrice(subtotal),
          ),

          // Discount line — only visible when a promo is applied.
          if (promoState.isApplied) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: AppLocalizations.of(context)!
                  .promoDiscount(promoState.appliedCode),
              value:
                  '− ${CurrencyFormatter.formatPrice(promoState.discountAmount)}',
              valueColor: AppColors.success,
              labelColor: AppColors.success,
            ),
          ],

          const SizedBox(height: 12),
          _SummaryRow(
            label: AppLocalizations.of(context)!.deliveryFee,
            value: CurrencyFormatter.formatPrice(deliveryFee),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          _SummaryRow(
            label: AppLocalizations.of(context)!.total,
            value: CurrencyFormatter.formatPrice(estimatedTotal),
            isBold: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String methodKey;
  final String selectedMethod;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.methodKey,
    required this.selectedMethod,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = methodKey == selectedMethod;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final Color? labelColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: labelColor ??
                  (isBold ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ??
                (isBold ? AppColors.textPrimary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
