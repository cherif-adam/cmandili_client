import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/map_address_picker.dart';
import '../../../checkout/data/models/delivery_address.dart';
import '../../../loyalty/data/loyalty_eligibility.dart';
import '../../../orders/presentation/order_success/order_success_screen.dart';
import '../../data/bill_type.dart';
import 'facture_controller.dart';
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
///   _BillTypeSection       Type de facture → BillTypeGrid
///   _BillDetailsSection    reference + amount fields, BillPhotoPicker
///   _AddressesSection      your address (cash pickup), office address
///   _PhoneSection          phone field
///   _PriceAndSendSection   FacturePriceSummary, SendRequestButton
///
/// UI only: the selection, the field rules and the order creation live in
/// [FactureController]. This screen keeps what belongs to the widget tree:
/// the text fields, the form key, the pickers, snackbars and navigation.
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
  /// This screen's own controller (see [factureControllerProvider]).
  late final _provider = factureControllerProvider(Object());

  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _referenceController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

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
            _BillTypeSection(
              selected: state.billType,
              onSelected: controller.selectBillType,
            ),
            const SizedBox(height: 20),
            _BillDetailsSection(
              referenceController: _referenceController,
              amountController: _amountController,
              validateReference: (v) =>
                  _fieldErrorText(controller.validateReference(v)),
              validateAmount: (v) =>
                  _fieldErrorText(controller.validateAmount(v)),
              photo: state.billPhoto,
              onAddPhoto: _showPhotoPicker,
              onRemovePhoto: controller.removeBillPhoto,
            ),
            const SizedBox(height: 20),
            _AddressesSection(
              customerAddress: state.customerAddress,
              officeAddress: state.officeAddress,
              billTypeLabel: state.billType?.label ?? '',
              onPickCustomerAddress: _pickCustomerAddress,
              onPickOfficeAddress: _pickOfficeAddress,
            ),
            const SizedBox(height: 20),
            _PhoneSection(
              phoneController: _phoneController,
              validatePhone: (v) =>
                  _fieldErrorText(controller.validatePhone(v)),
            ),
            const SizedBox(height: 20),
            _PriceAndSendSection(
              amountText: _amountController.text,
              loyaltyPreview: state.loyaltyPreview,
              submitting: state.submitting,
              onSend: _onSendPressed,
            ),
          ],
        ),
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

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

  Future<void> _pickPhoto(ImageSource source) async {
    final controller = ref.read(_provider.notifier);
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked != null && mounted) controller.setBillPhoto(File(picked.path));
  }

  Future<void> _pickCustomerAddress() async {
    final controller = ref.read(_provider.notifier);
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapAddressPicker(label: AppLocalizations.of(context)!.yourAddress),
      ),
    );
    if (address != null && mounted) controller.setCustomerAddress(address);
  }

  Future<void> _pickOfficeAddress() async {
    final controller = ref.read(_provider.notifier);
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapAddressPicker(label: AppLocalizations.of(context)!.paymentOffice),
      ),
    );
    if (address != null && mounted) controller.setOfficeAddress(address);
  }

  Future<void> _onSendPressed() async {
    final controller = ref.read(_provider.notifier);

    final missing = controller.missingInfo();
    if (missing != null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (missing) {
            FactureMissingInfo.billType => l10n.factureSelectBillType,
            FactureMissingInfo.customerAddress => l10n.factureEnterPickupAddress,
            FactureMissingInfo.officeAddress => l10n.factureEnterOfficeAddress,
          }),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    try {
      final orderId = await controller.submit(
        reference: _referenceController.text,
        amountText: _amountController.text,
        phone: _phoneController.text,
      );

      if (!mounted) return;
      controller.scheduleReminder();

      // push (not pushReplacement) — FactureScreen is an inline sliver on the
      // app's root HomeScreen route, so replacing it here would leave nothing
      // under the tracking screen for "back" to return to.
      final l10n = AppLocalizations.of(context)!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: orderId,
            imageAsset: 'assets/images/amana_facture_hero.jpg',
            title: l10n.factureSuccessTitle,
            trackButtonLabel: l10n.trackMyOrder,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.commonErrorWith(
              e is FactureNotSignedInException ? l10n.factureNotSignedIn : '$e')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// The translated text for a field rule the controller refused.
  String? _fieldErrorText(FactureFieldError? error) {
    if (error == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      FactureFieldError.referenceRequired => l10n.factureReferenceRequired,
      FactureFieldError.amountRequired => l10n.factureAmountRequired,
      FactureFieldError.invalidAmount => l10n.commonInvalidAmount,
      FactureFieldError.phoneRequired => l10n.facturePhoneRequired,
      FactureFieldError.invalidPhone => l10n.commonInvalidPhone8,
    };
  }
}

// ── Sections, in screen order ─────────────────────────────────────────────────

/// Type de facture → BillTypeGrid.
class _BillTypeSection extends StatelessWidget {
  const _BillTypeSection({required this.selected, required this.onSelected});

  final BillType? selected;
  final ValueChanged<BillType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactureSectionTitle(AppLocalizations.of(context)!.factureBillTypeTitle),
        const SizedBox(height: 10),
        BillTypeGrid(selected: selected, onSelected: onSelected),
      ],
    );
  }
}

/// Détails de la facture: reference, amount, optional photo.
class _BillDetailsSection extends StatelessWidget {
  const _BillDetailsSection({
    required this.referenceController,
    required this.amountController,
    required this.validateReference,
    required this.validateAmount,
    required this.photo,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final TextEditingController referenceController;
  final TextEditingController amountController;
  final FormFieldValidator<String> validateReference;
  final FormFieldValidator<String> validateAmount;
  final File? photo;
  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactureSectionTitle(l10n.billDetailsTitle),
        const SizedBox(height: 10),
        FactureTextField(
          controller: referenceController,
          label: l10n.factureReferenceLabel,
          icon: Icons.tag_rounded,
          textInputAction: TextInputAction.next,
          validator: validateReference,
        ),
        const SizedBox(height: 12),
        FactureTextField(
          controller: amountController,
          label: l10n.factureAmountLabel,
          icon: Icons.payments_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          textInputAction: TextInputAction.next,
          validator: validateAmount,
        ),
        const SizedBox(height: 12),
        BillPhotoPicker(
          photo: photo,
          onAdd: onAddPhoto,
          onRemove: onRemovePhoto,
        ),
      ],
    );
  }
}

/// Your address (where the cash is collected), then the office address
/// (where the driver pays).
class _AddressesSection extends StatelessWidget {
  const _AddressesSection({
    required this.customerAddress,
    required this.officeAddress,
    required this.billTypeLabel,
    required this.onPickCustomerAddress,
    required this.onPickOfficeAddress,
  });

  final DeliveryAddress? customerAddress;
  final DeliveryAddress? officeAddress;
  final String billTypeLabel;
  final VoidCallback onPickCustomerAddress;
  final VoidCallback onPickOfficeAddress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactureSectionTitle(l10n.factureCustomerAddressTitle),
        const SizedBox(height: 10),
        FactureAddressTile(
          address: customerAddress,
          placeholder: l10n.factureChooseYourAddress,
          icon: Icons.home_outlined,
          onTap: onPickCustomerAddress,
          color: kFactureOrange,
        ),
        const SizedBox(height: 16),
        FactureSectionTitle(l10n.factureOfficeAddressTitle(billTypeLabel)),
        const SizedBox(height: 10),
        FactureAddressTile(
          address: officeAddress,
          placeholder: l10n.factureChooseOfficeAddress,
          icon: Icons.business_outlined,
          onTap: onPickOfficeAddress,
          color: kFactureOrange,
        ),
      ],
    );
  }
}

/// Your phone number.
class _PhoneSection extends StatelessWidget {
  const _PhoneSection({
    required this.phoneController,
    required this.validatePhone,
  });

  final TextEditingController phoneController;
  final FormFieldValidator<String> validatePhone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactureSectionTitle(l10n.facturePhoneTitle),
        const SizedBox(height: 10),
        FactureTextField(
          controller: phoneController,
          label: l10n.facturePhoneLabel,
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          validator: validatePhone,
        ),
      ],
    );
  }
}

/// Price summary, then the send button.
class _PriceAndSendSection extends StatelessWidget {
  const _PriceAndSendSection({
    required this.amountText,
    required this.loyaltyPreview,
    required this.submitting,
    required this.onSend,
  });

  /// Read from the amount field when the screen rebuilds, as before.
  final String amountText;
  final LoyaltyMilestonePreview? loyaltyPreview;
  final bool submitting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FacturePriceSummary(
          amountText: amountText,
          serviceFee: FactureController.serviceFee,
          loyaltyPreview: loyaltyPreview,
        ),
        const SizedBox(height: 24),
        SendRequestButton(submitting: submitting, onPressed: onSend),
      ],
    );
  }
}
