import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/data/package_photo_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/map_address_picker.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../../orders/presentation/order_success_screen.dart';
import '../../bills/services/bill_reminder_service.dart';
import '../../loyalty/data/loyalty_eligibility.dart';
import '../../../core/utils/delivery_fee.dart';
import '../data/bill_type.dart';
import 'widgets/bill_photo_picker.dart';
import 'widgets/bill_type_grid.dart';
import 'widgets/facture_address_tile.dart';
import 'widgets/facture_colors.dart';
import 'widgets/facture_hero_banner.dart';
import 'widgets/facture_price_summary.dart';
import 'widgets/facture_section_title.dart';
import 'widgets/facture_text_field.dart';
import 'widgets/send_request_button.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// "Facture" (pay a bill for me), top to bottom:
///   FactureHeroBanner
///   Type de facture        → BillTypeGrid
///   Détails de la facture  → reference + amount fields, BillPhotoPicker
///   Votre adresse          → FactureAddressTile (where cash is collected)
///   Adresse du bureau      → FactureAddressTile (where the driver pays)
///   Téléphone              → phone field
///   FacturePriceSummary
///   SendRequestButton
///
/// _submitRequest() below uploads the optional photo and creates the
/// 'facture' order, then opens the success / tracking screen.
class FactureScreen extends ConsumerStatefulWidget {
  final double screenWidth;
  final double screenHeight;

  const FactureScreen({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  ConsumerState<FactureScreen> createState() => _FactureScreenState();
}

class _FactureScreenState extends ConsumerState<FactureScreen> {
  // Single source of truth for the flat rate — shared with supermarket
  // orders. Previously a second, independent hardcoded 5.000 that could
  // drift from kFlatDeliveryFee without anything noticing.
  static const _serviceFee = kFlatDeliveryFee;
  static const _tunisianPhone = r'^\d{8}$';

  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _photoStorage = PackagePhotoStorage();

  BillType? _selectedBillType;
  DeliveryAddress? _customerAddress;  // pickup (cash collection)
  DeliveryAddress? _officeAddress;    // delivery (where driver pays)
  File? _billPhoto;
  bool _submitting = false;

  // Preview only — the server's BEFORE INSERT trigger makes the real,
  // enforced determination at order creation.
  LoyaltyMilestonePreview? _loyaltyPreview;

  @override
  void initState() {
    super.initState();
    _loadLoyaltyPreview();
  }

  Future<void> _loadLoyaltyPreview() async {
    final preview = await predictNextOrderMilestone();
    if (mounted) setState(() => _loyaltyPreview = preview);
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Photo picker ─────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked != null) {
      setState(() => _billPhoto = File(picked.path));
    }
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(AppLocalizations.of(context)!.photoTakePicture),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(AppLocalizations.of(context)!.photoChooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCustomerAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapAddressPicker(label: AppLocalizations.of(context)!.yourAddress),
      ),
    );
    if (address != null) setState(() => _customerAddress = address);
  }

  Future<void> _selectOfficeAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapAddressPicker(label: AppLocalizations.of(context)!.paymentOffice),
      ),
    );
    if (address != null) setState(() => _officeAddress = address);
  }

  Future<String?> _uploadBillPhoto(String userId) async {
    if (_billPhoto == null) return null;
    try {
      final bytes = await _billPhoto!.readAsBytes();
      return await _photoStorage.uploadBillPhoto(userId, bytes);
    } catch (e) {
      return null;
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submitRequest() async {
    if (_selectedBillType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.factureSelectBillType)),
      );
      return;
    }
    if (_customerAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.factureEnterPickupAddress)),
      );
      return;
    }
    if (_officeAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.factureEnterOfficeAddress)),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw AppLocalizations.of(context)!.factureNotSignedIn;

      final billPhotoUrl = await _uploadBillPhoto(user.id);
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      final result = await _supabase
          .from('orders')
          .insert({
            'user_id': user.id,
            'order_type': 'facture',
            'status': 'ready',
            'pickup_address': _customerAddress!.toJson(),
            'delivery_address': _officeAddress!.toJson(),
            'bill_type': _selectedBillType!.dbValue,
            'bill_reference': _referenceController.text.trim(),
            'bill_amount': amount,
            if (billPhotoUrl != null) 'bill_photo_url': billPhotoUrl,
            'sender_phone': _phoneController.text.trim(),
            'delivery_fee': _serviceFee,
            'subtotal': 0,
            'total': _serviceFee,
            'payment_method': 'cash',
          })
          .select('id')
          .single();

      if (!mounted) return;

      // Schedule a reminder ~28 days from now for the same bill type.
      BillReminderService.instance.scheduleReminder(
        billType: _selectedBillType!.dbValue,
        billLabel: _selectedBillType!.label,
      ).catchError((_) {});

      // push (not pushReplacement) — FactureScreen is an inline sliver on the
      // app's root HomeScreen route, so replacing it here would leave nothing
      // under the tracking screen for "back" to return to.
      final l10n = AppLocalizations.of(context)!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: result['id'] as String,
            imageAsset: 'assets/images/amana_facture_hero.jpg',
            title: l10n.factureSuccessTitle,
            trackButtonLabel: l10n.trackMyOrder,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.commonErrorWith('$e')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Validators ────────────────────────────────────────────────────────

  String? _validateReference(String? v) {
    if (v == null || v.trim().isEmpty) {
      return AppLocalizations.of(context)!.factureReferenceRequired;
    }
    return null;
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) {
      return AppLocalizations.of(context)!.factureAmountRequired;
    }
    final parsed = double.tryParse(v.trim());
    if (parsed == null || parsed <= 0) {
      return AppLocalizations.of(context)!.commonInvalidAmount;
    }
    return null;
  }

  String? _validatePhone(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return AppLocalizations.of(context)!.facturePhoneRequired;
    if (!RegExp(_tunisianPhone).hasMatch(val)) {
      return AppLocalizations.of(context)!.commonInvalidPhone8;
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      // Bottom padding clears the floating bottom nav bar (~11.5% of screen
      // height) so the "Envoyer la demande" button isn't hidden under it —
      // matches the clearance used by SupermarketListScreen.
      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.screenHeight * 0.12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FactureHeroBanner(screenWidth: widget.screenWidth),
            const SizedBox(height: 20),

            // ── Bill type ─────────────────────────────────────────────────
            FactureSectionTitle(l10n.factureBillTypeTitle),
            const SizedBox(height: 10),
            BillTypeGrid(
              selected: _selectedBillType,
              onSelected: (type) => setState(() => _selectedBillType = type),
            ),
            const SizedBox(height: 20),

            // ── Bill details ──────────────────────────────────────────────
            FactureSectionTitle(l10n.billDetailsTitle),
            const SizedBox(height: 10),
            FactureTextField(
              controller: _referenceController,
              label: l10n.factureReferenceLabel,
              icon: Icons.tag_rounded,
              textInputAction: TextInputAction.next,
              validator: _validateReference,
            ),
            const SizedBox(height: 12),
            FactureTextField(
              controller: _amountController,
              label: l10n.factureAmountLabel,
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textInputAction: TextInputAction.next,
              validator: _validateAmount,
            ),
            const SizedBox(height: 12),
            BillPhotoPicker(
              photo: _billPhoto,
              onAdd: _showPhotoPicker,
              onRemove: () => setState(() => _billPhoto = null),
            ),
            const SizedBox(height: 20),

            // ── Addresses ─────────────────────────────────────────────────
            FactureSectionTitle(l10n.factureCustomerAddressTitle),
            const SizedBox(height: 10),
            FactureAddressTile(
              address: _customerAddress,
              placeholder: l10n.factureChooseYourAddress,
              icon: Icons.home_outlined,
              onTap: _selectCustomerAddress,
              color: kFactureOrange,
            ),
            const SizedBox(height: 16),
            FactureSectionTitle(
                l10n.factureOfficeAddressTitle(_selectedBillType?.label ?? '')),
            const SizedBox(height: 10),
            FactureAddressTile(
              address: _officeAddress,
              placeholder: l10n.factureChooseOfficeAddress,
              icon: Icons.business_outlined,
              onTap: _selectOfficeAddress,
              color: kFactureOrange,
            ),
            const SizedBox(height: 20),

            // ── Phone ─────────────────────────────────────────────────────
            FactureSectionTitle(l10n.facturePhoneTitle),
            const SizedBox(height: 10),
            FactureTextField(
              controller: _phoneController,
              label: l10n.facturePhoneLabel,
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              validator: _validatePhone,
            ),
            const SizedBox(height: 20),

            // ── Price + submit ────────────────────────────────────────────
            FacturePriceSummary(
              amountText: _amountController.text,
              serviceFee: _serviceFee,
              loyaltyPreview: _loyaltyPreview,
            ),
            const SizedBox(height: 24),
            SendRequestButton(
              submitting: _submitting,
              onPressed: _submitRequest,
            ),
          ],
        ),
      ),
    );
  }
}
