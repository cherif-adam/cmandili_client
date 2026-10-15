import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/delivery_fee.dart';
import '../data/colis_repository.dart';
import '../../../core/widgets/map_address_picker.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../../orders/presentation/order_success_screen.dart';
import '../../loyalty/data/loyalty_eligibility.dart';
import '../data/package_size.dart';
import '../data/saved_recipient.dart';
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
///   Pickup address        → CourierLocationCard (pre-filled from GPS)
///   SavedRecipientsSection (only if the user saved some)
///   Delivery address      → CourierLocationCard
///   CourierPriceCard      (once both addresses are set)
///   Sender phone, recipient name, recipient phone, SaveRecipientToggle
///   Contents, declared value
///   ForbiddenItemsCard
///   DeliveryModeSelector  (with code / without code)
///   PackagePhotoSection, PackageSizeSelector
///   ConfirmSendButton
///
/// _submitRequest() below uploads the photo and creates the parcel order
/// through ColisRepository, then opens the success / tracking screen.
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
  final _packageDescController = TextEditingController();
  final _declaredValueController = TextEditingController();
  final _receiverLabelController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  // ── Bon de prise en charge ────────────────────────────────────────────────
  final _colisRepo = ColisRepository();

  /// Plafond lu en base, pour qu'un admin le change sans livrer une version.
  /// La valeur de repli ne sert qu'à l'affichage : le serveur revalide.
  double _maxDeclaredValue = kColisFallbackMaxValue;

  ColisDeliveryMode _deliveryMode = ColisDeliveryMode.code;

  /// L'expéditeur confirme que son colis ne contient rien d'interdit.
  bool _forbiddenConfirmed = false;

  /// En remise sans code, il accepte que photo et GPS tiennent lieu de preuve.
  bool _noCodeAccepted = false;

  DeliveryAddress? _pickupAddress;
  DeliveryAddress? _dropoffAddress;
  PackageSize _packageSize = PackageSize.petit;

  bool _isLoadingLocation = false;
  bool _isCalculatingPrice = false;
  bool _isSubmitting = false;

  double? _estimatedDistanceKm;
  double? _estimatedPrice;

  // Preview only — the server's BEFORE INSERT trigger makes the real,
  // enforced determination at order creation.
  LoyaltyMilestonePreview? _loyaltyPreview;

  // Feature 2 — saved recipients
  List<SavedRecipient> _savedRecipients = [];
  bool _isLoadingSavedRecipients = false;
  bool _saveRecipient = false;

  // Feature 3 — package photo
  File? _packagePhoto;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _setInitialPickupLocation();
    _loadSavedRecipients();
    _loadLoyaltyPreview();
    _loadMaxDeclaredValue();
  }

  Future<void> _loadMaxDeclaredValue() async {
    final v = await _colisRepo.maxDeclaredValue();
    if (mounted) setState(() => _maxDeclaredValue = v);
  }

  Future<void> _loadLoyaltyPreview() async {
    final preview = await predictNextOrderMilestone();
    if (mounted) setState(() => _loyaltyPreview = preview);
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

  // ── Saved recipients ────────────────────────────────────────────────────────

  Future<void> _loadSavedRecipients() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoadingSavedRecipients = true);
    try {
      final rows = await Supabase.instance.client
          .from('saved_recipients')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _savedRecipients = (rows as List)
              .map((r) =>
                  SavedRecipient.fromJson(r as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      // Non-fatal: feature degrades silently
    } finally {
      if (mounted) setState(() => _isLoadingSavedRecipients = false);
    }
  }

  void _applyRecipient(SavedRecipient r) {
    setState(() {
      _recipientNameController.text = r.name ?? '';
      _recipientPhoneController.text = r.phone;
      if (r.deliveryAddress != null) {
        _dropoffAddress = r.deliveryAddress;
        _recalculatePrice();
      }
    });
  }

  Future<void> _deleteRecipient(String id) async {
    try {
      await Supabase.instance.client
          .from('saved_recipients')
          .delete()
          .eq('id', id);
      setState(() => _savedRecipients.removeWhere((r) => r.id == id));
    } catch (_) {}
  }

  Future<void> _persistRecipient(String userId) async {
    if (!_saveRecipient) return;
    final phone = _recipientPhoneController.text.trim();
    if (phone.isEmpty) return;
    await Supabase.instance.client.from('saved_recipients').insert({
      'user_id': userId,
      'name': _recipientNameController.text.trim().isEmpty
          ? null
          : _recipientNameController.text.trim(),
      'phone': phone,
      'delivery_address': _dropoffAddress?.toJson(),
    });
  }

  Future<void> _confirmDeleteRecipient(SavedRecipient r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce destinataire ?'),
        content: Text('${r.displayLabel} sera retiré de vos contacts enregistrés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteRecipient(r.id);
  }

  // ── Package photo ───────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _packagePhoto = File(picked.path));
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
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
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

  Future<String?> _uploadPhoto(String userId) async {
    if (_packagePhoto == null) return null;
    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await _packagePhoto!.readAsBytes();
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('package-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      return Supabase.instance.client.storage
          .from('package-photos')
          .getPublicUrl(path);
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Location helpers ────────────────────────────────────────────────────────

  Future<void> _setInitialPickupLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null && mounted) {
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
          _recalculatePrice();
        }
      }
    } catch (_) {
      // Non-fatal: user can select manually
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _selectPickupAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapAddressPicker(label: 'Adresse de ramassage'),
      ),
    );
    if (address != null) {
      setState(() => _pickupAddress = address);
      _recalculatePrice();
    }
  }

  Future<void> _selectDropoffAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapAddressPicker(label: 'Adresse de livraison'),
      ),
    );
    if (address != null) {
      setState(() => _dropoffAddress = address);
      _recalculatePrice();
    }
  }

  Future<void> _recalculatePrice() async {
    if (_pickupAddress == null || _dropoffAddress == null) return;
    setState(() => _isCalculatingPrice = true);
    try {
      final distKm = await tryDistanceKm(
        originLat: _pickupAddress!.latitude,
        originLng: _pickupAddress!.longitude,
        destLat: _dropoffAddress!.latitude,
        destLng: _dropoffAddress!.longitude,
      );
      if (mounted) {
        setState(() {
          _estimatedDistanceKm = distKm;
          _estimatedPrice = calculateDeliveryFee(distanceKm: distKm);
        });
      }
    } catch (_) {
      // Keep previous estimate
    } finally {
      if (mounted) setState(() => _isCalculatingPrice = false);
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submitRequest() async {
    // Trigger all validators and scroll into view automatically
    if (!_formKey.currentState!.validate()) return;

    if (_pickupAddress == null || _dropoffAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectPickupDropoff),
        ),
      );
      return;
    }

    // Les deux cases ne sont pas des champs de formulaire : un validator ne
    // les couvre pas, il faut les vérifier à la main.
    if (!_forbiddenConfirmed) {
      _snack('Confirmez que votre colis ne contient aucun article interdit.');
      return;
    }
    if (_deliveryMode == ColisDeliveryMode.noCode && !_noCodeAccepted) {
      _snack('Acceptez que la photo et la position tiennent lieu de preuve.');
      return;
    }

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSignInToContinue),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload photo first (if any) — non-blocking on failure
      final photoUrl = await _uploadPhoto(userId);

      final distanceKm = _estimatedDistanceKm ??
          await tryDistanceKm(
            originLat: _pickupAddress!.latitude,
            originLng: _pickupAddress!.longitude,
            destLat: _dropoffAddress!.latitude,
            destLng: _dropoffAddress!.longitude,
          );
      final deliveryFee = calculateDeliveryFee(distanceKm: distanceKm);

      // Plus d'insertion directe dans `orders` : create_colis_order écrit la
      // commande ET sa déclaration dans la même transaction. Un colis part en
      // broadcast dès sa création ; il ne doit jamais exister sans valeur
      // déclarée ni mode de remise, sinon un livreur peut l'accepter sans rien
      // qui le protège. Le serveur revalide aussi le plafond : le contrôle du
      // formulaire est du confort, celui-là est la règle.
      final orderId = await _colisRepo.createOrder(
        pickupAddress: _pickupAddress!.toJson(),
        deliveryAddress: _dropoffAddress!.toJson(),
        senderPhone: _senderPhoneController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        packageSize: _packageSize.name,
        description: _packageDescController.text.trim(),
        declaredValue:
            double.parse(_declaredValueController.text.trim().replaceAll(',', '.')),
        deliveryFee: deliveryFee,
        recipientName: _recipientNameController.text.trim().isEmpty
            ? null
            : _recipientNameController.text.trim(),
        mode: _deliveryMode,
        receiverLabel: _deliveryMode == ColisDeliveryMode.noCode
            ? _receiverLabelController.text.trim()
            : null,
        packagePhotoUrl: photoUrl,
      );

      // Persist saved recipient (non-fatal if it fails)
      try {
        await _persistRecipient(userId);
      } catch (_) {}

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
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Bon de prise en charge : saisie ───────────────────────────────────────

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  /// Le serveur revalide ce plafond. Ce validator évite juste à l'utilisateur
  /// de remplir tout le formulaire pour se faire refuser à la fin.
  String? _validateDeclaredValue(String? v) {
    final raw = (v ?? '').trim().replaceAll(',', '.');
    if (raw.isEmpty) return 'Indiquez la valeur de votre colis';
    final value = double.tryParse(raw);
    if (value == null) return 'Montant invalide';
    if (value <= 0) return 'La valeur doit être supérieure à 0';
    if (value > _maxDeclaredValue) {
      return 'Maximum ${_maxDeclaredValue.toStringAsFixed(0)} TND — '
          'scindez votre envoi';
    }
    return null;
  }

  String? _validatePackageDescription(String? v) =>
      (v ?? '').trim().isEmpty ? 'Décrivez le contenu de votre colis' : null;

  String? _validateReceiverLabel(String? v) {
    if (_deliveryMode != ColisDeliveryMode.noCode) return null;
    return (v ?? '').trim().isEmpty
        ? 'Indiquez à qui le colis sera remis'
        : null;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = widget.screenWidth;
    final h = widget.screenHeight;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(w * 0.05, h * 0.02, w * 0.05, h * 0.14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CourierHeroBanner(screenWidth: w),
            SizedBox(height: h * 0.03),

            // ── Pickup address ───────────────────────────────────────────────
            CourierSectionHeader('Adresse de ramassage', Icons.upload_rounded,
                screenWidth: w),
            SizedBox(height: h * 0.015),
            CourierLocationCard(
              label: 'Adresse de ramassage',
              address: _pickupAddress,
              icon: Icons.upload_rounded,
              color: AppColors.primary,
              onTap: _selectPickupAddress,
              isLoading: _isLoadingLocation,
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Saved recipients chips (above dropoff) ───────────────────────
            if (_savedRecipients.isNotEmpty || _isLoadingSavedRecipients)
              SavedRecipientsSection(
                isLoading: _isLoadingSavedRecipients,
                recipients: _savedRecipients,
                onSelect: _applyRecipient,
                onDelete: _confirmDeleteRecipient,
                screenWidth: w,
                screenHeight: h,
              ),

            // ── Dropoff address ──────────────────────────────────────────────
            CourierSectionHeader('Adresse de livraison', Icons.download_rounded,
                screenWidth: w),
            SizedBox(height: h * 0.015),
            CourierLocationCard(
              label: 'Adresse de livraison',
              address: _dropoffAddress,
              icon: Icons.download_rounded,
              color: const Color(0xFF2E7D32),
              onTap: _selectDropoffAddress,
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Price card ───────────────────────────────────────────────────
            if (_pickupAddress != null && _dropoffAddress != null)
              CourierPriceCard(
                isCalculating: _isCalculatingPrice,
                estimatedPrice: _estimatedPrice,
                estimatedDistanceKm: _estimatedDistanceKm,
                loyaltyPreview: _loyaltyPreview,
                screenWidth: w,
                screenHeight: h,
              ),
            SizedBox(height: h * 0.025),

            // ── Sender phone ─────────────────────────────────────────────────
            CourierSectionHeader('Téléphone de l\'expéditeur', Icons.phone_outlined,
                screenWidth: w),
            SizedBox(height: h * 0.008),
            CourierSectionHint('La personne qui remet le colis', screenWidth: w),
            SizedBox(height: h * 0.01),
            CourierPhoneField(
              controller: _senderPhoneController,
              icon: Icons.phone,
              requiredMessage: 'Obligatoire — numéro de l\'expéditeur',
              screenWidth: w,
            ),
            SizedBox(height: h * 0.025),

            // ── Recipient name (optional) ────────────────────────────────────
            CourierSectionHeader('Nom du destinataire', Icons.person_outline,
                screenWidth: w),
            SizedBox(height: h * 0.008),
            CourierSectionHint(
              'Optionnel — aide le livreur à identifier le destinataire',
              screenWidth: w,
            ),
            SizedBox(height: h * 0.01),
            CourierTextField(
              controller: _recipientNameController,
              hint: 'Ex: Mohamed Ben Ali',
              icon: Icons.person,
              screenWidth: w,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: h * 0.025),

            // ── Recipient phone ──────────────────────────────────────────────
            CourierSectionHeader(
                'Téléphone du destinataire', Icons.phone_forwarded_outlined,
                screenWidth: w),
            SizedBox(height: h * 0.008),
            CourierSectionHint('La personne qui reçoit le colis', screenWidth: w),
            SizedBox(height: h * 0.01),
            CourierPhoneField(
              controller: _recipientPhoneController,
              icon: Icons.phone_forwarded,
              requiredMessage: 'Obligatoire — numéro du destinataire',
              screenWidth: w,
            ),
            SaveRecipientToggle(
              value: _saveRecipient,
              onChanged: (v) => setState(() => _saveRecipient = v),
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Package description ──────────────────────────────────────────
            // Obligatoire désormais : c'est ce que le livreur confirme avoir
            // reçu, et ce qu'un admin lit en cas de litige. « Optionnel » ne
            // tient plus dès lors qu'on s'en sert comme preuve.
            CourierSectionHeader(
                'Que contient votre colis ?', Icons.description_outlined,
                screenWidth: w),
            SizedBox(height: h * 0.015),
            CourierTextField(
              controller: _packageDescController,
              hint: 'Ex : téléphone Samsung A15, documents, vêtements…',
              icon: Icons.description,
              screenWidth: w,
              maxLines: 2,
              validator: _validatePackageDescription,
            ),
            SizedBox(height: h * 0.025),

            // ── Valeur déclarée ──────────────────────────────────────────────
            CourierSectionHeader('Valeur déclarée', Icons.sell_outlined,
                screenWidth: w),
            SizedBox(height: h * 0.008),
            CourierSectionHint(
              'Plafond : ${_maxDeclaredValue.toStringAsFixed(0)} TND. Au-delà, '
              'scindez votre envoi en plusieurs colis.',
              screenWidth: w,
            ),
            SizedBox(height: h * 0.015),
            CourierTextField(
              controller: _declaredValueController,
              hint: 'Valeur en TND',
              icon: Icons.payments_outlined,
              screenWidth: w,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _validateDeclaredValue,
            ),
            SizedBox(height: h * 0.025),

            // ── Articles interdits ───────────────────────────────────────────
            ForbiddenItemsCard(
              confirmed: _forbiddenConfirmed,
              onConfirmedChanged: (v) => setState(() => _forbiddenConfirmed = v),
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Mode de remise ───────────────────────────────────────────────
            CourierSectionHeader(
                'Remise au destinataire', Icons.verified_user_outlined,
                screenWidth: w),
            SizedBox(height: h * 0.015),
            DeliveryModeSelector(
              mode: _deliveryMode,
              onModeChanged: (mode) => setState(() => _deliveryMode = mode),
              receiverLabelController: _receiverLabelController,
              receiverLabelValidator: _validateReceiverLabel,
              noCodeAccepted: _noCodeAccepted,
              onNoCodeAcceptedChanged: (v) => setState(() => _noCodeAccepted = v),
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Package photo ────────────────────────────────────────────────
            CourierSectionHeader('Photo du colis', Icons.camera_alt_outlined,
                screenWidth: w),
            SizedBox(height: h * 0.008),
            CourierSectionHint(
              'Optionnel — aide le livreur à identifier votre colis',
              screenWidth: w,
            ),
            SizedBox(height: h * 0.015),
            PackagePhotoSection(
              photo: _packagePhoto,
              onPick: _showPhotoPicker,
              onRemove: () => setState(() => _packagePhoto = null),
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Package size ─────────────────────────────────────────────────
            CourierSectionHeader('Taille du colis', Icons.straighten_outlined,
                screenWidth: w),
            SizedBox(height: h * 0.015),
            PackageSizeSelector(
              selected: _packageSize,
              onSelected: (size) => setState(() => _packageSize = size),
              screenWidth: w,
              screenHeight: h,
            ),
            SizedBox(height: h * 0.035),

            // ── Submit button ────────────────────────────────────────────────
            ConfirmSendButton(
              isBusy: _isSubmitting || _isUploadingPhoto,
              estimatedPrice: _estimatedPrice,
              onPressed: _submitRequest,
              screenWidth: w,
              screenHeight: h,
            ),
          ],
        ),
      ),
    );
  }
}
