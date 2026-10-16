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

enum PackageSize { petit, moyen, grand }

// ── Local model for saved recipients ─────────────────────────────────────────

class _SavedRecipient {
  final String id;
  final String? name;
  final String phone;
  final DeliveryAddress? deliveryAddress;

  _SavedRecipient({
    required this.id,
    this.name,
    required this.phone,
    this.deliveryAddress,
  });

  String get displayLabel =>
      (name != null && name!.isNotEmpty) ? name! : phone;

  factory _SavedRecipient.fromJson(Map<String, dynamic> json) {
    return _SavedRecipient(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String,
      deliveryAddress: json['delivery_address'] != null
          ? DeliveryAddress.fromJson(
              json['delivery_address'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

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
  List<_SavedRecipient> _savedRecipients = [];
  bool _isLoadingSavedRecipients = false;
  bool _saveRecipient = false;

  // Feature 3 — package photo
  File? _packagePhoto;
  bool _isUploadingPhoto = false;

  static const _purple = Color(0xFF6C3DE1);
  static const _tunisianPhone = r'^\d{8}$';

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
                  _SavedRecipient.fromJson(r as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      // Non-fatal: feature degrades silently
    } finally {
      if (mounted) setState(() => _isLoadingSavedRecipients = false);
    }
  }

  void _applyRecipient(_SavedRecipient r) {
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = widget.screenWidth;
    final h = widget.screenHeight;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(w * 0.05, h * 0.02, w * 0.05, h * 0.14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero banner ───────────────────────────────────────────────────
            _buildHeroBanner(w),
            SizedBox(height: h * 0.03),

            // ── Pickup address ───────────────────────────────────────────────
            _buildSectionHeader('Adresse de ramassage', Icons.upload_rounded, w, h),
            SizedBox(height: h * 0.015),
            _buildLocationSelector(
              label: 'Adresse de ramassage',
              address: _pickupAddress,
              icon: Icons.upload_rounded,
              color: AppColors.primary,
              onTap: _selectPickupAddress,
              isLoading: _isLoadingLocation,
              w: w, h: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Saved recipients chips (above dropoff) ───────────────────────
            if (_savedRecipients.isNotEmpty || _isLoadingSavedRecipients)
              _buildSavedRecipientsSection(w, h),

            // ── Dropoff address ──────────────────────────────────────────────
            _buildSectionHeader('Adresse de livraison', Icons.download_rounded, w, h),
            SizedBox(height: h * 0.015),
            _buildLocationSelector(
              label: 'Adresse de livraison',
              address: _dropoffAddress,
              icon: Icons.download_rounded,
              color: const Color(0xFF2E7D32),
              onTap: _selectDropoffAddress,
              w: w, h: h,
            ),
            SizedBox(height: h * 0.025),

            // ── Price card ───────────────────────────────────────────────────
            if (_pickupAddress != null && _dropoffAddress != null)
              _buildPriceCard(w, h),
            SizedBox(height: h * 0.025),

            // ── Sender phone ─────────────────────────────────────────────────
            _buildSectionHeader('Téléphone de l\'expéditeur', Icons.phone_outlined, w, h),
            SizedBox(height: h * 0.008),
            Text(
              'La personne qui remet le colis',
              style: TextStyle(fontSize: w * 0.032, color: AppColors.textSecondary),
            ),
            SizedBox(height: h * 0.01),
            TextFormField(
              controller: _senderPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 8,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _inputDecoration(
                'Ex: 20123456',
                Icons.phone,
                w,
              ).copyWith(counterText: ''),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Obligatoire — numéro de l\'expéditeur';
                if (!RegExp(_tunisianPhone).hasMatch(val)) {
                  return 'Numéro invalide — exactement 8 chiffres requis';
                }
                return null;
              },
            ),
            SizedBox(height: h * 0.025),

            // ── Recipient name (optional) ────────────────────────────────────
            _buildSectionHeader('Nom du destinataire', Icons.person_outline, w, h),
            SizedBox(height: h * 0.008),
            Text(
              'Optionnel — aide le livreur à identifier le destinataire',
              style: TextStyle(fontSize: w * 0.032, color: AppColors.textSecondary),
            ),
            SizedBox(height: h * 0.01),
            TextFormField(
              controller: _recipientNameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Ex: Mohamed Ben Ali', Icons.person, w),
            ),
            SizedBox(height: h * 0.025),

            // ── Recipient phone ──────────────────────────────────────────────
            _buildSectionHeader('Téléphone du destinataire', Icons.phone_forwarded_outlined, w, h),
            SizedBox(height: h * 0.008),
            Text(
              'La personne qui reçoit le colis',
              style: TextStyle(fontSize: w * 0.032, color: AppColors.textSecondary),
            ),
            SizedBox(height: h * 0.01),
            TextFormField(
              controller: _recipientPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 8,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _inputDecoration(
                'Ex: 20123456',
                Icons.phone_forwarded,
                w,
              ).copyWith(counterText: ''),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Obligatoire — numéro du destinataire';
                if (!RegExp(_tunisianPhone).hasMatch(val)) {
                  return 'Numéro invalide — exactement 8 chiffres requis';
                }
                return null;
              },
            ),

            // ── Save recipient toggle ────────────────────────────────────────
            _buildSaveRecipientToggle(w, h),
            SizedBox(height: h * 0.025),

            // ── Package description ──────────────────────────────────────────
            // Obligatoire désormais : c'est ce que le livreur confirme avoir
            // reçu, et ce qu'un admin lit en cas de litige. « Optionnel » ne
            // tient plus dès lors qu'on s'en sert comme preuve.
            _buildSectionHeader('Que contient votre colis ?',
                Icons.description_outlined, w, h),
            SizedBox(height: h * 0.015),
            TextFormField(
              controller: _packageDescController,
              maxLines: 2,
              decoration: _inputDecoration(
                'Ex : téléphone Samsung A15, documents, vêtements…',
                Icons.description,
                w,
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Décrivez le contenu de votre colis'
                  : null,
            ),
            SizedBox(height: h * 0.025),

            // ── Valeur déclarée ──────────────────────────────────────────────
            _buildSectionHeader('Valeur déclarée', Icons.sell_outlined, w, h),
            SizedBox(height: h * 0.008),
            Text(
              'Plafond : ${_maxDeclaredValue.toStringAsFixed(0)} TND. Au-delà, '
              'scindez votre envoi en plusieurs colis.',
              style: TextStyle(
                  fontSize: w * 0.032, color: AppColors.textSecondary),
            ),
            SizedBox(height: h * 0.015),
            TextFormField(
              controller: _declaredValueController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('Valeur en TND', Icons.payments_outlined, w),
              validator: _validateDeclaredValue,
            ),
            SizedBox(height: h * 0.025),

            // ── Articles interdits ───────────────────────────────────────────
            _buildForbiddenItems(w, h),
            SizedBox(height: h * 0.025),

            // ── Mode de remise ───────────────────────────────────────────────
            // Le titre pose la question au lieu de nommer un réglage :
            // « Remise au destinataire » ne dit pas à l'expéditeur ce qu'on
            // attend de lui.
            _buildSectionHeader(l10n.colisHandoverSectionTitle,
                Icons.verified_user_outlined, w, h),
            SizedBox(height: h * 0.015),
            _buildDeliveryModeSelector(w, h),
            SizedBox(height: h * 0.025),

            // ── Package photo ────────────────────────────────────────────────
            _buildSectionHeader('Photo du colis', Icons.camera_alt_outlined, w, h),
            SizedBox(height: h * 0.008),
            Text(
              'Optionnel — aide le livreur à identifier votre colis',
              style: TextStyle(fontSize: w * 0.032, color: AppColors.textSecondary),
            ),
            SizedBox(height: h * 0.015),
            _buildPhotoSection(w, h),
            SizedBox(height: h * 0.025),

            // ── Package size ─────────────────────────────────────────────────
            _buildSectionHeader('Taille du colis', Icons.straighten_outlined, w, h),
            SizedBox(height: h * 0.015),
            _buildPackageSizeSelector(w, h),
            SizedBox(height: h * 0.035),

            // ── Submit button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: h * 0.07,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _isUploadingPhoto) ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(w * 0.04),
                  ),
                  elevation: 4,
                ),
                child: (_isSubmitting || _isUploadingPhoto)
                    ? const CircularProgressIndicator(color: Colors.white)
                    // FittedBox plutôt qu'une ellipse : « Confirmer l'env… »
                    // ou un prix tronqué sur le bouton d'envoi serait pire que
                    // des caractères un peu plus petits. La Row débordait de
                    // 18 à 31 px dès que le prix estimé s'affichait à côté du
                    // libellé — mainAxisSize.min pour qu'elle soit mesurée à
                    // sa largeur naturelle avant d'être réduite.
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded),
                            SizedBox(width: w * 0.02),
                            Text(
                              'Confirmer l\'envoi',
                              style: TextStyle(
                                fontSize: w * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_estimatedPrice != null) ...[
                              SizedBox(width: w * 0.02),
                              Text(
                                '• ${_estimatedPrice!.toStringAsFixed(3)} TND',
                                style: TextStyle(
                                  fontSize: w * 0.038,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget builders ─────────────────────────────────────────────────────────

  Widget _buildHeroBanner(double w) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 110,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/amana_colis_handover.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.4),
              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.emeraldBannerGradient),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sendParcelTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: w * 0.05,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.sendParcelSubtitle,
                    style: TextStyle(
                      color: AppColors.orderSuccessSubtitleMint,
                      fontSize: w * 0.032,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedRecipientsSection(double w, double h) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bookmarks_outlined, color: _purple, size: 16),
            SizedBox(width: w * 0.015),
            Text(
              'Destinataires enregistrés',
              style: TextStyle(
                fontSize: w * 0.035,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: h * 0.01),
        if (_isLoadingSavedRecipients)
          const SizedBox(
            height: 36,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
              ),
            ),
          )
        else
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _savedRecipients.length,
              separatorBuilder: (_, __) => SizedBox(width: w * 0.02),
              itemBuilder: (context, i) {
                final r = _savedRecipients[i];
                return GestureDetector(
                  onTap: () => _applyRecipient(r),
                  onLongPress: () => _confirmDeleteRecipient(r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.035,
                      vertical: h * 0.006,
                    ),
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: w * 0.04, color: _purple),
                        SizedBox(width: w * 0.01),
                        Text(
                          r.displayLabel,
                          style: TextStyle(
                            color: _purple,
                            fontSize: w * 0.033,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: w * 0.015),
                        GestureDetector(
                          onTap: () => _confirmDeleteRecipient(r),
                          child: Icon(
                            Icons.close,
                            size: w * 0.038,
                            color: _purple.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        SizedBox(height: h * 0.02),
      ],
    );
  }

  Future<void> _confirmDeleteRecipient(_SavedRecipient r) async {
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

  Widget _buildSaveRecipientToggle(double w, double h) {
    return Padding(
      padding: EdgeInsets.only(top: h * 0.01),
      child: InkWell(
        onTap: () => setState(() => _saveRecipient = !_saveRecipient),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.012,
          ),
          decoration: BoxDecoration(
            color: _saveRecipient
                ? _purple.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _saveRecipient
                  ? _purple.withValues(alpha: 0.4)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _saveRecipient
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _saveRecipient ? _purple : AppColors.textSecondary,
                size: w * 0.055,
              ),
              SizedBox(width: w * 0.03),
              Expanded(
                child: Text(
                  'Enregistrer ce destinataire pour la prochaine fois',
                  style: TextStyle(
                    fontSize: w * 0.036,
                    fontWeight:
                        _saveRecipient ? FontWeight.w600 : FontWeight.normal,
                    color: _saveRecipient ? _purple : AppColors.textSecondary,
                  ),
                ),
              ),
              Switch(
                value: _saveRecipient,
                onChanged: (v) => setState(() => _saveRecipient = v),
                activeColor: _purple,
                activeTrackColor: _purple.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(double w, double h) {
    if (_packagePhoto != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.04),
            child: Image.file(
              _packagePhoto!,
              width: double.infinity,
              height: h * 0.22,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _packagePhoto = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: _showPhotoPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Changer',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _showPhotoPicker,
      child: Container(
        width: double.infinity,
        // minHeight et non height : la boîte était dimensionnée par la HAUTEUR
        // de l'écran (h * 0.14) alors que son contenu — icône et deux lignes —
        // est dimensionné par la LARGEUR. Sur un téléphone large le contenu
        // débordait par le bas de 0,1 à 9,8 px. Avec un minimum, la boîte
        // garde la même taille quand ça rentre et grandit quand il faut.
        constraints: BoxConstraints(minHeight: h * 0.14),
        padding: EdgeInsets.symmetric(vertical: h * 0.012),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: w * 0.1,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: h * 0.008),
            Text(
              'Ajouter une photo du colis',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: w * 0.035,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: h * 0.004),
            Text(
              'Appuyer pour prendre/choisir une photo',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: w * 0.03,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(double w, double h) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C3DE1), Color(0xFF9C6DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(w * 0.04),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _isCalculatingPrice
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          : Row(
              children: [
                Container(
                  padding: EdgeInsets.all(w * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: w * 0.07),
                ),
                SizedBox(width: w * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loyaltyPreview == null
                            ? 'Prix estimé'
                            : _loyaltyPreview!.type == 'free'
                                ? 'Prix estimé — fidélité : livraison gratuite'
                                : 'Prix estimé — fidélité : -50%',
                        style: TextStyle(
                            color: Colors.white70, fontSize: w * 0.033),
                      ),
                      SizedBox(height: h * 0.004),
                      if (_estimatedPrice != null && _loyaltyPreview != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${_estimatedPrice!.toStringAsFixed(3)} TND',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: w * 0.04,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            SizedBox(width: w * 0.02),
                            Text(
                              '${(_estimatedPrice! * (1 - _loyaltyPreview!.discountMultiplier)).toStringAsFixed(3)} TND',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w * 0.06,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          _estimatedPrice != null
                              ? '${_estimatedPrice!.toStringAsFixed(3)} TND'
                              : '...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: w * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (_estimatedDistanceKm != null)
                        Text(
                          '${_estimatedDistanceKm!.toStringAsFixed(1)} km',
                          style: TextStyle(
                              color: Colors.white70, fontSize: w * 0.032),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('3.500 TND base',
                        style: TextStyle(
                            color: Colors.white60, fontSize: w * 0.028)),
                    Text('+0.500/km > 3km',
                        style: TextStyle(
                            color: Colors.white60, fontSize: w * 0.028)),
                  ],
                ),
              ],
            ),
    );
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

  Widget _buildForbiddenItems(double w, double h) {
    return Container(
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD9A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interdit dans un colis',
            style: TextStyle(
                fontSize: w * 0.038, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: h * 0.012),
          ...kColisForbiddenItems.map((item) => Padding(
                padding: EdgeInsets.only(bottom: h * 0.006),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: TextStyle(fontSize: w * 0.038)),
                    SizedBox(width: w * 0.025),
                    Expanded(
                      child: Text(item.$2,
                          style: TextStyle(
                              fontSize: w * 0.034,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              )),
          SizedBox(height: h * 0.004),
          // La case vient APRÈS la liste : on ne confirme pas à l'aveugle.
          CheckboxListTile(
            value: _forbiddenConfirmed,
            onChanged: (v) =>
                setState(() => _forbiddenConfirmed = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: Text(
              'Je confirme que mon colis ne contient aucun de ces articles',
              style: TextStyle(fontSize: w * 0.034),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryModeSelector(double w, double h) {
    final l10n = AppLocalizations.of(context)!;

    Widget option({
      required ColisDeliveryMode mode,
      required String title,
      required String subtitle,
      required IconData icon,
      String? badge,
    }) {
      final selected = _deliveryMode == mode;
      return InkWell(
        onTap: () => setState(() => _deliveryMode = mode),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(w * 0.035),
          margin: EdgeInsets.only(bottom: h * 0.012),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: w * 0.055),
              SizedBox(width: w * 0.03),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Flexible : à l'étroit, c'est le titre qui se coupe,
                        // jamais le badge — un « Recommandé » tronqué en
                        // « Recomm… » n'aide personne.
                        Flexible(
                          child: Text(title,
                              style: TextStyle(
                                  fontSize: w * 0.038,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (badge != null) ...[
                          SizedBox(width: w * 0.02),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: w * 0.02, vertical: h * 0.003),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                  fontSize: w * 0.028,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: h * 0.004),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: w * 0.031,
                            color: AppColors.textSecondary,
                            height: 1.3)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.primary, size: w * 0.05),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // L'ordre n'est pas neutre : le mode recommandé est aussi celui par
        // défaut (_deliveryMode) et passe donc en premier.
        option(
          mode: ColisDeliveryMode.code,
          title: l10n.colisModeCodeTitle,
          subtitle: l10n.colisModeCodeSubtitle,
          icon: Icons.lock_outline,
          badge: l10n.colisModeRecommended,
        ),
        option(
          mode: ColisDeliveryMode.noCode,
          title: l10n.colisModeNoCodeTitle,
          subtitle: l10n.colisModeNoCodeSubtitle,
          icon: Icons.handshake_outlined,
        ),
        if (_deliveryMode == ColisDeliveryMode.noCode) ...[
          SizedBox(height: h * 0.004),
          TextFormField(
            controller: _receiverLabelController,
            decoration: _inputDecoration(
                "Ex : Gardien de l'école, voisin du 3e…",
                Icons.person_pin_circle_outlined,
                w),
            validator: (v) {
              if (_deliveryMode != ColisDeliveryMode.noCode) return null;
              return (v ?? '').trim().isEmpty
                  ? 'Indiquez à qui le colis sera remis'
                  : null;
            },
          ),
          CheckboxListTile(
            value: _noCodeAccepted,
            onChanged: (v) => setState(() => _noCodeAccepted = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: Text(
              "J'accepte que la preuve de remise soit la photo et la position "
              'du livreur.',
              style: TextStyle(fontSize: w * 0.034),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPackageSizeSelector(double w, double h) {
    final sizes = [
      (PackageSize.petit, 'Petit', '📄', 'Documents, petits objets'),
      (PackageSize.moyen, 'Moyen', '📦', 'Vêtements, accessoires'),
      (PackageSize.grand, 'Grand', '🧳', 'Bagages, gros colis'),
    ];

    return Row(
      children: sizes.map((entry) {
        final (size, label, icon, desc) = entry;
        final isSelected = _packageSize == size;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _packageSize = size),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: w * 0.01),
              padding: EdgeInsets.symmetric(
                  vertical: h * 0.015, horizontal: w * 0.01),
              decoration: BoxDecoration(
                color: isSelected ? _purple : Colors.white,
                borderRadius: BorderRadius.circular(w * 0.03),
                border: Border.all(
                  color:
                      isSelected ? _purple : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? _purple.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(icon, style: TextStyle(fontSize: w * 0.07)),
                  SizedBox(height: h * 0.005),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: w * 0.033,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: h * 0.003),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: w * 0.025,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, double w, double h) {
    return Row(
      children: [
        Icon(icon, color: _purple, size: w * 0.055),
        SizedBox(width: w * 0.02),
        // Expanded, sinon le titre pousse la Row au-delà de l'écran : sans
        // contrainte il se dessine à sa largeur naturelle. Plusieurs en-têtes
        // de cette page débordaient déjà de 37 à 48 px ; « Comment le livreur
        // remet votre colis ? » est plus long et portait le débordement à
        // plus de 250 px. Contraint, le titre passe simplement à la ligne.
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: w * 0.042,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, double w) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(w * 0.03),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(w * 0.03),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(w * 0.03),
        borderSide: const BorderSide(color: _purple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(w * 0.03),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(w * 0.03),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildLocationSelector({
    required String label,
    required DeliveryAddress? address,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double w,
    required double h,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(w * 0.04),
      child: Container(
        padding: EdgeInsets.all(w * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(
            color: address != null
                ? color.withValues(alpha: 0.4)
                : Colors.grey.shade300,
            width: address != null ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.025),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? SizedBox(
                      width: w * 0.06,
                      height: w * 0.06,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon, color: color, size: w * 0.06),
            ),
            SizedBox(width: w * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: w * 0.032, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: h * 0.004),
                  Text(
                    address?.fullAddress ?? 'Appuyez pour sélectionner',
                    style: TextStyle(
                      fontSize: w * 0.038,
                      fontWeight: FontWeight.w600,
                      color: address != null
                          ? AppColors.textPrimary
                          : Colors.grey.shade400,
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
