import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/delivery_fee.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../../checkout/presentation/address_selection_screen.dart';
import '../../orders/presentation/order_tracking_screen.dart';

class CourierScreen extends ConsumerStatefulWidget {
  final double screenWidth;
  final double screenHeight;

  const CourierScreen({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  ConsumerState<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends ConsumerState<CourierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _packageDescController = TextEditingController();
  
  DeliveryAddress? _pickupAddress;
  DeliveryAddress? _dropoffAddress;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _setInitialPickupLocation();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _packageDescController.dispose();
    super.dispose();
  }

  Future<void> _setInitialPickupLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final addressText = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          setState(() {
            _pickupAddress = DeliveryAddress(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              label: AppLocalizations.of(context)!.currentLocation,
              fullAddress: addressText,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          });
        }
      }
    } catch (e) {
      // Handle error gently
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _selectPickupAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (context) => const AddressSelectionScreen()),
    );
    if (address != null) {
      setState(() => _pickupAddress = address);
    }
  }

  Future<void> _selectDropoffAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (context) => const AddressSelectionScreen()),
    );
    if (address != null) {
      setState(() => _dropoffAddress = address);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupAddress == null || _dropoffAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectPickupDropoff)),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSignInToContinue), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Courier base fee is 5 DT for the partner platform; the standard
      // 3 DT minimum + 0.5 DT/km past 4 km still applies on top so the
      // driver gets paid fairly for long pickups.
      const courierBaseFee = 5.0;
      const courierSubtotal = 10.0;
      final distanceKm = await tryDistanceKm(
        originLat: _pickupAddress?.latitude,
        originLng: _pickupAddress?.longitude,
        destLat: _dropoffAddress?.latitude,
        destLng: _dropoffAddress?.longitude,
      );
      final deliveryFee = calculateDeliveryFee(
        partnerFlatFee: courierBaseFee,
        distanceKm: distanceKm,
      );
      final total = courierSubtotal + deliveryFee;

      final response = await supabase.from('orders').insert({
        'user_id': userId,
        'status': 'pending',
        'subtotal': courierSubtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'payment_method': 'cash',
        'notes': _packageDescController.text,
        'delivery_address': _dropoffAddress!.toJson(),
        'pickup_address': _pickupAddress!.toJson(),
        'order_type': 'courier',
        'recipient_name': _recipientNameController.text.trim(),
        'recipient_phone': _recipientPhoneController.text.trim(),
        'package_description': _packageDescController.text.trim(),
        'estimated_delivery_time': DateTime.now().add(const Duration(minutes: 45)).toIso8601String(),
      }).select('id').single();

      final orderId = response['id'] as String;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create courier request: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        widget.screenWidth * 0.05,
        widget.screenHeight * 0.02,
        widget.screenWidth * 0.05,
        widget.screenHeight * 0.12,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(AppLocalizations.of(context)!.recipientDetails, Icons.person_outline),
            SizedBox(height: widget.screenHeight * 0.02),
            _buildTextField(
              controller: _recipientNameController,
              label: AppLocalizations.of(context)!.friendsName,
              icon: Icons.person,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            SizedBox(height: widget.screenHeight * 0.02),
            _buildTextField(
              controller: _recipientPhoneController,
              label: AppLocalizations.of(context)!.phoneNumber,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),

            SizedBox(height: widget.screenHeight * 0.03),
            _buildSectionHeader(AppLocalizations.of(context)!.packageDetails, Icons.inventory_2_outlined),
            SizedBox(height: widget.screenHeight * 0.02),
            _buildTextField(
              controller: _packageDescController,
              label: AppLocalizations.of(context)!.whatAreYouSending,
              icon: Icons.description,
              maxLines: 2,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),

            SizedBox(height: widget.screenHeight * 0.03),
            _buildSectionHeader(AppLocalizations.of(context)!.locations, Icons.map_outlined),
            SizedBox(height: widget.screenHeight * 0.02),

            // Pickup Location
            _buildLocationSelector(
              label: AppLocalizations.of(context)!.pickupLocation,
              address: _pickupAddress,
              icon: Icons.upload_rounded,
              color: AppColors.primary,
              onTap: _selectPickupAddress,
              isLoading: _isLoadingLocation,
            ),
            SizedBox(height: widget.screenHeight * 0.02),

            // Dropoff Location
            _buildLocationSelector(
              label: AppLocalizations.of(context)!.dropoffLocation,
              address: _dropoffAddress,
              icon: Icons.download_rounded,
              color: AppColors.secondary,
              onTap: _selectDropoffAddress,
            ),

            SizedBox(height: widget.screenHeight * 0.04),
            SizedBox(
              width: double.infinity,
              height: widget.screenHeight * 0.07,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(widget.screenWidth * 0.04),
                  ),
                  elevation: 4,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        AppLocalizations.of(context)!.requestCourier,
                        style: TextStyle(
                          fontSize: widget.screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: widget.screenWidth * 0.06),
        SizedBox(width: widget.screenWidth * 0.02),
        Text(
          title,
          style: TextStyle(
            fontSize: widget.screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.screenWidth * 0.03),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.screenWidth * 0.03),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.screenWidth * 0.03),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildLocationSelector({
    required String label,
    required DeliveryAddress? address,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(widget.screenWidth * 0.04),
      child: Container(
        padding: EdgeInsets.all(widget.screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.screenWidth * 0.04),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(widget.screenWidth * 0.025),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? SizedBox(
                      width: widget.screenWidth * 0.06,
                      height: widget.screenWidth * 0.06,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: color, size: widget.screenWidth * 0.06),
            ),
            SizedBox(width: widget.screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: widget.screenWidth * 0.035,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: widget.screenHeight * 0.005),
                  Text(
                    address?.fullAddress ?? 'Tap to select location',
                    style: TextStyle(
                      fontSize: widget.screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                      color: address != null ? AppColors.textPrimary : Colors.grey.shade400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
