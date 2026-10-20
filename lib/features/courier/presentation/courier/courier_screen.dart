import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/map_address_picker.dart';
import '../../../checkout/data/models/delivery_address.dart';
import '../../../orders/presentation/order_success/order_success_screen.dart';
import '../../data/colis_repository.dart';
import '../../data/package_size.dart';
import '../../data/saved_recipient.dart';
import 'courier_controller.dart';
import 'widgets/confirm_send_button.dart';
import 'widgets/courier_hero_banner.dart';
import 'widgets/courier_location_card.dart';
import 'widgets/courier_phone_field.dart';
import 'widgets/courier_price_card.dart';
import 'widgets/courier_section_header.dart';
import 'widgets/courier_section_hint.dart';
import 'widgets/courier_text_field.dart';
import 'widgets/delivery_mode_selector.dart';
import 'widgets/forbidden_items_card.dart';
import 'widgets/package_photo_section.dart';
import 'widgets/package_size_selector.dart';
import 'widgets/save_recipient_toggle.dart';
import 'widgets/saved_recipients_section.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// "Colis" (send a parcel), top to bottom:
///   CourierHeroBanner
///   _PickupSection          Pickup address → CourierLocationCard (from GPS)
///   _DropoffSection         SavedRecipientsSection (only if the user saved
///                           some), Delivery address → CourierLocationCard
///   CourierPriceCard        (once both addresses are set)
///   _SenderPhoneSection, _RecipientNameSection,
///   _RecipientPhoneSection  (with SaveRecipientToggle)
///   _DescriptionSection, _DeclaredValueSection
///   ForbiddenItemsCard
///   _HandoverModeSection    DeliveryModeSelector (with code / without code)
///   _PhotoSection           PackagePhotoSection
///   _SizeSection            PackageSizeSelector
///   ConfirmSendButton
///
/// UI only: the selection, the price estimate, the field rules, the photo
/// upload and the order creation live in [CourierController]. This screen
/// keeps what belongs to the widget tree: the text fields, the form key, the
/// pickers, dialogs, snackbars and navigation.
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
  /// This screen's own controller (see [courierControllerProvider]).
  late final _provider = courierControllerProvider(Object());

  final _formKey = GlobalKey<FormState>();
  final _packageDescController = TextEditingController();
  final _declaredValueController = TextEditingController();
  final _receiverLabelController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(_provider.notifier).start(
          currentLocationLabel: () =>
              AppLocalizations.of(context)!.currentLocation,
        );
  }

  @override
  void dispose() {
    _packageDescController.dispose();
    _declaredValueController.dispose();
    _receiverLabelController.dispose();
    _senderPhoneController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.screenWidth;
    final h = widget.screenHeight;
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(w * 0.05, h * 0.02, w * 0.05, h * 0.14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CourierHeroBanner(screenWidth: w),
            SizedBox(height: h * 0.03),
            _PickupSection(
              address: state.pickupAddress,
              isLoading: state.isLoadingLocation,
              onTap: _selectPickupAddress,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            _DropoffSection(
              savedRecipients: state.savedRecipients,
              isLoadingSavedRecipients: state.isLoadingSavedRecipients,
              onSelectRecipient: _applyRecipient,
              onDeleteRecipient: _confirmDeleteRecipient,
              address: state.dropoffAddress,
              onTap: _selectDropoffAddress,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            if (state.pickupAddress != null && state.dropoffAddress != null)
              CourierPriceCard(
                isCalculating: state.isCalculatingPrice,
                estimatedPrice: state.estimatedPrice,
                estimatedDistanceKm: state.estimatedDistanceKm,
                loyaltyPreview: state.loyaltyPreview,
                screenWidth: w,
                screenHeight: h,
              ),
            SizedBox(height: h * 0.025),
            _SenderPhoneSection(
              controller: _senderPhoneController,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            _RecipientNameSection(
              controller: _recipientNameController,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            _RecipientPhoneSection(
              controller: _recipientPhoneController,
              saveRecipient: state.saveRecipient,
              onSaveRecipientChanged: controller.setSaveRecipient,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            _DescriptionSection(
              controller: _packageDescController,
              validator: (v) =>
                  _fieldErrorText(controller.validatePackageDescription(v)),
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            _DeclaredValueSection(
              controller: _declaredValueController,
              maxDeclaredValue: state.maxDeclaredValue,
              validator: (v) =>
                  _fieldErrorText(controller.validateDeclaredValue(v)),
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            ForbiddenItemsCard(
              confirmed: state.forbiddenConfirmed,
              onConfirmedChanged: controller.setForbiddenConfirmed,
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.025),
            _HandoverModeSection(
              mode: state.deliveryMode,
              onModeChanged: controller.setDeliveryMode,
              receiverLabelController: _receiverLabelController,
              receiverLabelValidator: (v) =>
                  _fieldErrorText(controller.validateReceiverLabel(v)),
              noCodeAccepted: state.noCodeAccepted,
              onNoCodeAcceptedChanged: controller.setNoCodeAccepted,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            _PhotoSection(
              photo: state.packagePhoto,
              onPick: _showPhotoPicker,
              onRemove: controller.removePackagePhoto,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.025),
            _SizeSection(
              selected: state.packageSize,
              onSelected: controller.setPackageSize,
              w: w,
              h: h,
            ),
            SizedBox(height: h * 0.035),
            ConfirmSendButton(
              isBusy: state.isSubmitting || state.isUploadingPhoto,
              estimatedPrice: state.estimatedPrice,
              onPressed: _submitRequest,
              screenWidth: w,
              screenHeight: h,
            ),
          ],
        ),
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void _applyRecipient(SavedRecipient r) {
    _recipientNameController.text = r.name ?? '';
    _recipientPhoneController.text = r.phone;
    ref.read(_provider.notifier).applyRecipientAddress(r);
  }

  Future<void> _confirmDeleteRecipient(SavedRecipient r) async {
    final controller = ref.read(_provider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.courierDeleteRecipientTitle),
        content: Text(AppLocalizations.of(context)!
            .courierDeleteRecipientBody(r.displayLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.deleteRecipient(r.id);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final controller = ref.read(_provider.notifier);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      controller.setPackagePhoto(File(picked.path));
    }
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(AppLocalizations.of(context)!.photoTakePicture),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppLocalizations.of(context)!.photoChooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPickupAddress() async {
    final controller = ref.read(_provider.notifier);
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => MapAddressPicker(
            label: AppLocalizations.of(context)!.courierPickupAddress),
      ),
    );
    if (address != null && mounted) controller.setPickupAddress(address);
  }

  Future<void> _selectDropoffAddress() async {
    final controller = ref.read(_provider.notifier);
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => MapAddressPicker(
            label: AppLocalizations.of(context)!.deliveryAddress),
      ),
    );
    if (address != null && mounted) controller.setDropoffAddress(address);
  }

  Future<void> _submitRequest() async {
    // Trigger all validators and scroll into view automatically
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(_provider.notifier);
    switch (controller.blocker()) {
      case CourierBlocker.missingAddresses:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.pleaseSelectPickupDropoff),
          ),
        );
        return;
      case CourierBlocker.forbiddenNotConfirmed:
        _snack(AppLocalizations.of(context)!.courierConfirmNoForbidden);
        return;
      case CourierBlocker.photoProofNotAccepted:
        _snack(AppLocalizations.of(context)!.courierAcceptPhotoProof);
        return;
      case CourierBlocker.notSignedIn:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSignInToContinue),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      case null:
        break;
    }

    try {
      final orderId = await controller.submit(_readFields);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              orderId: orderId,
              imageAsset: 'assets/images/amana_colis_handover.jpg',
              title: l10n.parcelSuccessTitle,
              trackButtonLabel: l10n.trackMyParcel,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericErrorWith('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Read by the controller when it builds the order (see
  /// [CourierController.submit]).
  CourierFields _readFields() => (
        senderPhone: _senderPhoneController.text,
        recipientName: _recipientNameController.text,
        recipientPhone: _recipientPhoneController.text,
        description: _packageDescController.text,
        declaredValue: _declaredValueController.text,
        receiverLabel: _receiverLabelController.text,
      );

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String? _fieldErrorText(CourierFieldError? error) {
    if (error == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      CourierFieldError.descriptionRequired => l10n.courierDescriptionRequired,
      CourierFieldError.declaredValueRequired =>
        l10n.courierDeclaredValueRequired,
      CourierFieldError.invalidAmount => l10n.commonInvalidAmount,
      CourierFieldError.declaredValueNotPositive =>
        l10n.courierDeclaredValuePositive,
      CourierFieldError.declaredValueTooHigh => l10n.courierDeclaredValueMax(
          ref.read(_provider).maxDeclaredValue.toStringAsFixed(0)),
      CourierFieldError.receiverLabelRequired =>
        l10n.courierReceiverLabelRequired,
    };
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _PickupSection extends StatelessWidget {
  const _PickupSection({
    required this.address,
    required this.isLoading,
    required this.onTap,
    required this.w,
    required this.h,
  });

  final DeliveryAddress? address;
  final bool isLoading;
  final VoidCallback onTap;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(l10n.courierPickupAddress, Icons.upload_rounded,
            screenWidth: w),
        SizedBox(height: h * 0.015),
        CourierLocationCard(
          label: l10n.courierPickupAddress,
          address: address,
          icon: Icons.upload_rounded,
          color: AppColors.primary,
          onTap: onTap,
          isLoading: isLoading,
          screenWidth: w,
          screenHeight: h,
        ),
      ],
    );
  }
}

/// Saved recipients chips (above dropoff), then the delivery address.
class _DropoffSection extends StatelessWidget {
  const _DropoffSection({
    required this.savedRecipients,
    required this.isLoadingSavedRecipients,
    required this.onSelectRecipient,
    required this.onDeleteRecipient,
    required this.address,
    required this.onTap,
    required this.w,
    required this.h,
  });

  final List<SavedRecipient> savedRecipients;
  final bool isLoadingSavedRecipients;
  final ValueChanged<SavedRecipient> onSelectRecipient;
  final ValueChanged<SavedRecipient> onDeleteRecipient;
  final DeliveryAddress? address;
  final VoidCallback onTap;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (savedRecipients.isNotEmpty || isLoadingSavedRecipients)
          SavedRecipientsSection(
            isLoading: isLoadingSavedRecipients,
            recipients: savedRecipients,
            onSelect: onSelectRecipient,
            onDelete: onDeleteRecipient,
            screenWidth: w,
            screenHeight: h,
          ),
        CourierSectionHeader(l10n.deliveryAddress, Icons.download_rounded,
            screenWidth: w),
        SizedBox(height: h * 0.015),
        CourierLocationCard(
          label: l10n.deliveryAddress,
          address: address,
          icon: Icons.download_rounded,
          color: const Color(0xFF2E7D32),
          onTap: onTap,
          screenWidth: w,
          screenHeight: h,
        ),
      ],
    );
  }
}

class _SenderPhoneSection extends StatelessWidget {
  const _SenderPhoneSection({
    required this.controller,
    required this.w,
    required this.h,
  });

  final TextEditingController controller;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(l10n.courierSenderPhone, Icons.phone_outlined,
            screenWidth: w),
        SizedBox(height: h * 0.008),
        CourierSectionHint(l10n.courierSenderPhoneHint, screenWidth: w),
        SizedBox(height: h * 0.01),
        CourierPhoneField(
          controller: controller,
          icon: Icons.phone,
          requiredMessage: l10n.courierSenderPhoneRequired,
          screenWidth: w,
        ),
      ],
    );
  }
}

/// Recipient name (optional).
class _RecipientNameSection extends StatelessWidget {
  const _RecipientNameSection({
    required this.controller,
    required this.w,
    required this.h,
  });

  final TextEditingController controller;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(l10n.courierRecipientName, Icons.person_outline,
            screenWidth: w),
        SizedBox(height: h * 0.008),
        CourierSectionHint(
          l10n.courierRecipientNameHint,
          screenWidth: w,
        ),
        SizedBox(height: h * 0.01),
        CourierTextField(
          controller: controller,
          hint: l10n.courierRecipientNameExample,
          icon: Icons.person,
          screenWidth: w,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}

class _RecipientPhoneSection extends StatelessWidget {
  const _RecipientPhoneSection({
    required this.controller,
    required this.saveRecipient,
    required this.onSaveRecipientChanged,
    required this.w,
    required this.h,
  });

  final TextEditingController controller;
  final bool saveRecipient;
  final ValueChanged<bool> onSaveRecipientChanged;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(
            l10n.courierRecipientPhone, Icons.phone_forwarded_outlined,
            screenWidth: w),
        SizedBox(height: h * 0.008),
        CourierSectionHint(l10n.courierRecipientPhoneHint, screenWidth: w),
        SizedBox(height: h * 0.01),
        CourierPhoneField(
          controller: controller,
          icon: Icons.phone_forwarded,
          requiredMessage: l10n.courierRecipientPhoneRequired,
          screenWidth: w,
        ),
        SaveRecipientToggle(
          value: saveRecipient,
          onChanged: onSaveRecipientChanged,
          screenWidth: w,
          screenHeight: h,
        ),
      ],
    );
  }
}

/// Package description.
///
/// Obligatoire désormais : c'est ce que le livreur confirme avoir reçu, et ce
/// qu'un admin lit en cas de litige. « Optionnel » ne tient plus dès lors
/// qu'on s'en sert comme preuve.
class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({
    required this.controller,
    required this.validator,
    required this.w,
    required this.h,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(
            l10n.courierContentsTitle, Icons.description_outlined,
            screenWidth: w),
        SizedBox(height: h * 0.015),
        CourierTextField(
          controller: controller,
          hint: l10n.courierContentsExample,
          icon: Icons.description,
          screenWidth: w,
          maxLines: 2,
          validator: validator,
        ),
      ],
    );
  }
}

/// Valeur déclarée, avec le plafond chargé en base.
class _DeclaredValueSection extends StatelessWidget {
  const _DeclaredValueSection({
    required this.controller,
    required this.maxDeclaredValue,
    required this.validator,
    required this.w,
    required this.h,
  });

  final TextEditingController controller;
  final double maxDeclaredValue;
  final FormFieldValidator<String> validator;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(l10n.courierDeclaredValue, Icons.sell_outlined,
            screenWidth: w),
        SizedBox(height: h * 0.008),
        CourierSectionHint(
          l10n.courierDeclaredValueCap(maxDeclaredValue.toStringAsFixed(0)),
          screenWidth: w,
        ),
        SizedBox(height: h * 0.015),
        CourierTextField(
          controller: controller,
          hint: l10n.courierDeclaredValueHint,
          icon: Icons.payments_outlined,
          screenWidth: w,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
        ),
      ],
    );
  }
}

/// Mode de remise.
///
/// Le titre pose la question au lieu de nommer un réglage : « Remise au
/// destinataire » ne dit pas à l'expéditeur ce qu'on attend de lui.
class _HandoverModeSection extends StatelessWidget {
  const _HandoverModeSection({
    required this.mode,
    required this.onModeChanged,
    required this.receiverLabelController,
    required this.receiverLabelValidator,
    required this.noCodeAccepted,
    required this.onNoCodeAcceptedChanged,
    required this.w,
    required this.h,
  });

  final ColisDeliveryMode mode;
  final ValueChanged<ColisDeliveryMode> onModeChanged;
  final TextEditingController receiverLabelController;
  final FormFieldValidator<String> receiverLabelValidator;
  final bool noCodeAccepted;
  final ValueChanged<bool> onNoCodeAcceptedChanged;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(
            l10n.colisHandoverSectionTitle, Icons.verified_user_outlined,
            screenWidth: w),
        SizedBox(height: h * 0.015),
        DeliveryModeSelector(
          mode: mode,
          onModeChanged: onModeChanged,
          receiverLabelController: receiverLabelController,
          receiverLabelValidator: receiverLabelValidator,
          noCodeAccepted: noCodeAccepted,
          onNoCodeAcceptedChanged: onNoCodeAcceptedChanged,
          screenWidth: w,
          screenHeight: h,
        ),
      ],
    );
  }
}

/// Package photo.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photo,
    required this.onPick,
    required this.onRemove,
    required this.w,
    required this.h,
  });

  final File? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(l10n.courierPhotoTitle, Icons.camera_alt_outlined,
            screenWidth: w),
        SizedBox(height: h * 0.008),
        CourierSectionHint(
          l10n.courierPhotoHint,
          screenWidth: w,
        ),
        SizedBox(height: h * 0.015),
        PackagePhotoSection(
          photo: photo,
          onPick: onPick,
          onRemove: onRemove,
          screenWidth: w,
          screenHeight: h,
        ),
      ],
    );
  }
}

/// Package size.
class _SizeSection extends StatelessWidget {
  const _SizeSection({
    required this.selected,
    required this.onSelected,
    required this.w,
    required this.h,
  });

  final PackageSize selected;
  final ValueChanged<PackageSize> onSelected;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierSectionHeader(l10n.courierSizeTitle, Icons.straighten_outlined,
            screenWidth: w),
        SizedBox(height: h * 0.015),
        PackageSizeSelector(
          selected: selected,
          onSelected: onSelected,
          screenWidth: w,
          screenHeight: h,
        ),
      ],
    );
  }
}
