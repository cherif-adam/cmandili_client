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
  bool _isPlacingOrder = false;
  final String _selectedPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    // Auto-fill name + phone from the user's profile so they don't retype on
    // every order. Best-effort — silently leaves fields empty on failure.
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
    super.dispose();
  }

  Future<void> _selectAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressSelectionScreen(),
      ),
    );

    if (address != null) {
      setState(() {
        _selectedAddress = address;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectAddress),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseEnterPhone),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final cartItems = ref.read(cartProvider);
      final firstItem = cartItems.isNotEmpty ? cartItems.first : null;
      final restaurantId = firstItem?.foodItem?.restaurantId;
      final supermarketId = firstItem?.groceryItem?.supermarketId;
      final orderType = supermarketId != null ? OrderType.supermarket : OrderType.food;

      // Compute delivery fee + distance now that we have an address. The
      // partner's flat fee is the base; we add 0.5 DT/km past 4 km and floor
      // the result at 3 DT (see calculateDeliveryFee). Pickup coords come
      // from the relevant restaurant/supermarket row pulled via Supabase
      // directly — fast and avoids needing every screen to ferry coords
      // through widget params.
      double partnerFlatFee = widget.deliveryFee; // safe fallback
      double? pickupLat;
      double? pickupLng;
      try {
        if (restaurantId != null) {
          final r = await Supabase.instance.client
              .from('restaurants')
              .select('delivery_fee, latitude, longitude')
              .eq('id', restaurantId)
              .maybeSingle();
          if (r != null) {
            partnerFlatFee = (r['delivery_fee'] as num?)?.toDouble() ?? partnerFlatFee;
            pickupLat = (r['latitude'] as num?)?.toDouble();
            pickupLng = (r['longitude'] as num?)?.toDouble();
          }
        } else if (supermarketId != null) {
          final s = await Supabase.instance.client
              .from('supermarkets')
              .select('delivery_fee, latitude, longitude')
              .eq('id', supermarketId)
              .maybeSingle();
          if (s != null) {
            partnerFlatFee = (s['delivery_fee'] as num?)?.toDouble() ?? partnerFlatFee;
            pickupLat = (s['latitude'] as num?)?.toDouble();
            pickupLng = (s['longitude'] as num?)?.toDouble();
          }
        }
      } catch (_) {
        // Network hiccup → keep partnerFlatFee as fallback; floor still applies.
      }

      final distanceKm = await tryDistanceKm(
        originLat: pickupLat,
        originLng: pickupLng,
        destLat: _selectedAddress!.latitude,
        destLng: _selectedAddress!.longitude,
      );
      final finalDeliveryFee = calculateDeliveryFee(
        partnerFlatFee: partnerFlatFee,
        distanceKm: distanceKm,
      );
      final finalSubtotal = widget.subtotal;
      final finalTotal = finalSubtotal + finalDeliveryFee;

      // Stamp the contact info onto the address so the partner & driver can
      // read it back from delivery_address.recipientName / .phone without an
      // extra join.
      final addressWithContact = _selectedAddress!.copyWith(
        recipientName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        phone: phone,
      );

      // Persist phone back to the user's profile so future checkouts auto-fill.
      // Fire-and-forget — order creation must not depend on this.
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        Supabase.instance.client.from('profiles').update({
          'phone': phone,
          if (_nameController.text.trim().isNotEmpty) 'full_name': _nameController.text.trim(),
        }).eq('id', userId).then((_) {}, onError: (_) {});
      }

      // Create order in 'awaiting_payment' state first
      final orderId = await ref.read(orderRepositoryProvider).createOrder(
        items: cartItems,
        deliveryAddress: addressWithContact,
        subtotal: finalSubtotal,
        deliveryFee: finalDeliveryFee,
        total: finalTotal,
        orderType: orderType,
        restaurantId: restaurantId,
        supermarketId: supermarketId,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        paymentMethod: _selectedPaymentMethod,
        distanceKm: distanceKm,
      );

      if (!mounted) return;

      // Process payment
      final paymentResult = await PaymentService().processAndRecord(
        orderId: orderId,
        amount: finalTotal,
        methodKey: _selectedPaymentMethod,
        context: context,
      );

      if (!mounted) return;

      if (!paymentResult.success) {
        // Cancel the order on payment failure
        await ref.read(orderRepositoryProvider).cancelOrder(orderId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentResult.errorMessage ?? 'Payment failed. Order cancelled.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Confirm order now that payment succeeded
      await ref.read(orderRepositoryProvider).confirmOrder(orderId);

      // Clear cart
      ref.read(cartProvider.notifier).clearCart();

      // Navigate to order tracking with real orderId
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(orderId: orderId),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery Address Section
                  Text(
                    AppLocalizations.of(context)!.deliveryAddress,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  InkWell(
                    onTap: _selectAddress,
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
                          color: _selectedAddress != null
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: _selectedAddress == null
                          ? Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_location_alt_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  AppLocalizations.of(context)!.selectDeliveryAddress,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Spacer(),
                                Icon(
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
                                        _selectedAddress!.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedAddress!.fullAddress,
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
                                const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Contact info — name + phone for the driver
                  Text(
                    AppLocalizations.of(context)!.contactInfo,
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.fullNameHint,
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.textLight),
                            border: InputBorder.none,
                          ),
                        ),
                        const Divider(height: 1),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
                          ],
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.phoneHint,
                            prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textLight),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Payment Method
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
                  
                  // Order Notes
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
                        hintText: AppLocalizations.of(context)!.specialDeliveryInstructions,
                        hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Order Summary
                  Text(
                    AppLocalizations.of(context)!.orderSummary,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
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
                          value: CurrencyFormatter.formatPrice(widget.subtotal),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: AppLocalizations.of(context)!.deliveryFee,
                          value: CurrencyFormatter.formatPrice(widget.deliveryFee),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(),
                        ),
                        _SummaryRow(
                          label: AppLocalizations.of(context)!.total,
                          value: CurrencyFormatter.formatPrice(widget.total),
                          isBold: true,
                          valueColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Place Order Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                          'Place Order - ${CurrencyFormatter.formatPrice(widget.total)}',
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

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? (isBold ? AppColors.textPrimary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
