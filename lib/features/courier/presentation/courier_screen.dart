import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/delivery_fee.dart';
import '../../../core/widgets/map_address_picker.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../../orders/presentation/order_tracking_screen.dart';

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
  final _senderPhoneController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  DeliveryAddress? _pickupAddress;
  DeliveryAddress? _dropoffAddress;
  PackageSize _packageSize = PackageSize.petit;

  bool _isLoadingLocation = false;
  bool _isCalculatingPrice = false;
  bool _isSubmitting = false;

  double? _estimatedDistanceKm;
  double? _estimatedPrice;

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
  }

  @override
  void dispose() {
    _packageDescController.dispose();
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

      final response = await supabase.from('orders').insert({
        'user_id': userId,
        'status': 'ready',
        'subtotal': 0.0,
        'delivery_fee': deliveryFee,
        'total': deliveryFee,
        'payment_method': 'cash',
        'notes': _packageDescController.text.trim().isEmpty
            ? null
            : _packageDescController.text.trim(),
        'delivery_address': _dropoffAddress!.toJson(),
        'pickup_address': _pickupAddress!.toJson(),
        'order_type': 'courier',
        'package_description': _packageDescController.text.trim().isEmpty
            ? null
            : _packageDescController.text.trim(),
        'package_size': _packageSize.name,
        'sender_phone': _senderPhoneController.text.trim(),
        'recipient_name': _recipientNameController.text.trim().isEmpty
            ? null
            : _recipientNameController.text.trim(),
        'recipient_phone': _recipientPhoneController.text.trim(),
        if (photoUrl != null) 'package_photo_url': photoUrl,
        'estimated_delivery_time':
            DateTime.now().add(const Duration(minutes: 45)).toIso8601String(),
      }).select('id').single();

      // Persist saved recipient (non-fatal if it fails)
      try {
        await _persistRecipient(userId);
      } catch (_) {}

      final orderId = response['id'] as String;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId, justPlaced: true),
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(w * 0.05, h * 0.02, w * 0.05, h * 0.14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _buildSectionHeader('Envoyer un colis', Icons.inventory_2_outlined, w, h),
            SizedBox(height: h * 0.008),
            Text(
              'Envoyez n\'importe quel article d\'un point A à un point B',
              style: TextStyle(fontSize: w * 0.035, color: AppColors.textSecondary),
            ),
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
            _buildSectionHeader('Description du colis', Icons.description_outlined, w, h),
            SizedBox(height: h * 0.015),
            TextFormField(
              controller: _packageDescController,
              maxLines: 2,
              decoration: _inputDecoration(
                'Ex: documents, vêtements, chaussures… (optionnel)',
                Icons.description,
                w,
              ),
            ),
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
                    : Row(
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
          ],
        ),
      ),
    );
  }

  // ── Widget builders ─────────────────────────────────────────────────────────

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
        height: h * 0.14,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
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
                        'Prix estimé',
                        style: TextStyle(
                            color: Colors.white70, fontSize: w * 0.033),
                      ),
                      SizedBox(height: h * 0.004),
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
        Text(
          title,
          style: TextStyle(
            fontSize: w * 0.042,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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
