import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/delivery_address.dart';
import '../address_selection/address_selection_screen.dart';
import '../../../orders/presentation/order_tracking/order_tracking_screen.dart';
import '../../../orders/presentation/order_success/order_success_screen.dart';
import '../../../orders/data/models/order.dart';
import '../../../promo/presentation/promo_error_text.dart';
import '../../../promo/providers/promo_provider.dart';
import '../../../loyalty/data/loyalty_eligibility.dart';
import 'checkout_controller.dart';
import 'widgets/checkout_address_picker.dart';
import 'widgets/checkout_section_title.dart';
import 'widgets/order_notes_field.dart';
import 'widgets/place_order_bar.dart';
import 'widgets/checkout_contact_card.dart';
import 'widgets/promo_code_field.dart';
import 'widgets/order_summary_card.dart';
import 'widgets/payment_option_tile.dart';

/// "Commande", top to bottom:
///   _AddressSection   delivery address
///   _ContactSection   name and phone
///   _PaymentSection   payment method
///   _NotesSection     order notes
///   _PromoSection     promo code
///   _SummarySection   order summary
/// then the PlaceOrderBar.
///
/// UI only: the address, the promo preview and placing the order (venue
/// check, promo commit, delivery fee, order creation, payment, undo on
/// failure) live in [CheckoutController]. This screen keeps the text fields,
/// the address picker, the messages and the navigation.
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
  /// This screen's own controller (see [checkoutControllerProvider]).
  late final _provider = checkoutControllerProvider(Object());

  final _notesController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _promoCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillContactFromProfile();
  }

  Future<void> _prefillContactFromProfile() async {
    try {
      final contact = await ref.read(_provider.notifier).loadContact();
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

  @override
  Widget build(BuildContext context) {
    final promoState = ref.watch(promoProvider);
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    final totals = checkoutPreviewTotals(
      subtotal: widget.subtotal,
      deliveryFee: widget.deliveryFee,
      promoState: promoState,
      loyaltyPreview: state.loyaltyPreview,
    );

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
                  _AddressSection(
                    selectedAddress: state.selectedAddress,
                    onTap: _selectAddress,
                  ),
                  const SizedBox(height: 32),
                  _ContactSection(
                    nameController: _nameController,
                    phoneController: _phoneController,
                  ),
                  const SizedBox(height: 32),
                  const _PaymentSection(
                    selectedMethod: CheckoutController.selectedPaymentMethod,
                  ),
                  const SizedBox(height: 32),
                  _NotesSection(controller: _notesController),
                  const SizedBox(height: 32),
                  _PromoSection(
                    controller: _promoCodeController,
                    promoState: promoState,
                    onApply: () => controller
                        .previewPromo(_promoCodeController.text.trim()),
                    onRemove: () {
                      _promoCodeController.clear();
                      controller.removePromo();
                    },
                  ),
                  const SizedBox(height: 32),
                  _SummarySection(
                    subtotal: widget.subtotal,
                    deliveryFee: widget.deliveryFee,
                    estimatedTotal: totals.estimatedTotal,
                    promoState: promoState,
                    loyaltyPreview: state.loyaltyPreview,
                    loyaltyDiscountAmount: totals.loyaltyDiscount,
                  ),
                ],
              ),
            ),
          ),

          PlaceOrderBar(
            isPlacingOrder: state.isPlacingOrder,
            estimatedTotal: totals.estimatedTotal,
            onPressed: _placeOrder,
          ),
        ],
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _selectAddress() async {
    final controller = ref.read(_provider.notifier);
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (context) => const AddressSelectionScreen()),
    );
    if (address != null && mounted) controller.selectAddress(address);
  }

  Future<void> _placeOrder() async {
    final outcome = await ref.read(_provider.notifier).placeOrder(
          context: context,
          subtotal: widget.subtotal,
          fields: _readFields(),
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    switch (outcome) {
      case CheckoutMissingAddress():
        _showSnack(l10n.pleaseSelectAddress);
      case CheckoutMissingPhone():
        _showSnack(l10n.pleaseEnterPhone);
      case CheckoutVenueClosed():
        _showSnack(l10n.venueClosedNow);
      case CheckoutPromoRefused(:final response):
        // The promo state is already reset: clear the field and surface the
        // server's error message.
        _promoCodeController.clear();
        _showSnack(promoErrorText(l10n, response));
      case CheckoutPaymentRefused(:final message):
        _showSnack(message ?? l10n.paymentFailedOrderCancelled);
      case CheckoutFailed(:final error):
        _showSnack(l10n.genericErrorWith(error.toString()));
      case CheckoutPlaced(:final orderId, :final orderType):
        // Supermarket (and boutique, which shares order_type 'supermarket')
        // orders get the success hand-off screen; food orders keep the
        // existing straight-to-tracking behavior unchanged.
        if (orderType == OrderType.supermarket) {
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
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// What the customer typed, as it is when Commander is tapped.
  CheckoutFields _readFields() => (
        name: _nameController.text,
        phone: _phoneController.text,
        notes: _notesController.text,
      );

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
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _AddressSection extends StatelessWidget {
  const _AddressSection({required this.selectedAddress, required this.onTap});

  final DeliveryAddress? selectedAddress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionTitle(AppLocalizations.of(context)!.deliveryAddress),
        const SizedBox(height: 16),
        CheckoutAddressPicker(
          selectedAddress: selectedAddress,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.nameController,
    required this.phoneController,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionTitle(AppLocalizations.of(context)!.contactInfo),
        const SizedBox(height: 16),
        CheckoutContactCard(
          nameController: nameController,
          phoneController: phoneController,
        ),
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.selectedMethod});

  final String selectedMethod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionTitle(AppLocalizations.of(context)!.paymentMethod),
        const SizedBox(height: 16),
        PaymentOptionTile(
          icon: Icons.payments_outlined,
          iconColor: AppColors.success,
          title: AppLocalizations.of(context)!.cashOnDelivery,
          subtitle: AppLocalizations.of(context)!.payWhenYouReceive,
          methodKey: 'cash',
          selectedMethod: selectedMethod,
          onTap: () {},
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionTitle(AppLocalizations.of(context)!.orderNotes),
        const SizedBox(height: 16),
        OrderNotesField(controller: controller),
      ],
    );
  }
}

class _PromoSection extends StatelessWidget {
  const _PromoSection({
    required this.controller,
    required this.promoState,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final PromoState promoState;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionTitle(AppLocalizations.of(context)!.promoCode),
        const SizedBox(height: 16),
        PromoCodeField(
          controller: controller,
          promoState: promoState,
          onApply: onApply,
          onRemove: onRemove,
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.subtotal,
    required this.deliveryFee,
    required this.estimatedTotal,
    required this.promoState,
    required this.loyaltyPreview,
    required this.loyaltyDiscountAmount,
  });

  final double subtotal;
  final double deliveryFee;
  final double estimatedTotal;
  final PromoState promoState;
  final LoyaltyMilestonePreview? loyaltyPreview;
  final double loyaltyDiscountAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionTitle(AppLocalizations.of(context)!.orderSummary),
        const SizedBox(height: 16),
        OrderSummaryCard(
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          estimatedTotal: estimatedTotal,
          promoState: promoState,
          loyaltyPreview: loyaltyPreview,
          loyaltyDiscountAmount: loyaltyDiscountAmount,
        ),
      ],
    );
  }
}
