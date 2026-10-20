import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/package_photo_storage.dart';
import '../../../../core/utils/delivery_fee.dart';
import '../../../../core/utils/location_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../checkout/data/models/delivery_address.dart';
import '../../../loyalty/data/loyalty_eligibility.dart';
import '../../data/colis_repository.dart';
import '../../data/package_size.dart';
import '../../data/saved_recipient.dart';
import '../../data/saved_recipient_repository.dart';

/// One controller per Colis screen on display. The argument is a key the
/// screen creates for itself: the home tab and the AI chat can each show a
/// Colis form at the same time, and they must not share their selection.
/// Auto-disposed with the screen, like the State it replaces.
final courierControllerProvider = NotifierProvider.autoDispose
    .family<CourierController, CourierState, Object>(CourierController.new);

/// What the user typed in the form's text fields, untrimmed.
typedef CourierFields = ({
  String senderPhone,
  String recipientName,
  String recipientPhone,
  String description,
  String declaredValue,
  String receiverLabel,
});

/// Why the parcel cannot be sent yet, in the order the screen checks it.
enum CourierBlocker {
  missingAddresses,
  forbiddenNotConfirmed,
  photoProofNotAccepted,
  notSignedIn,
}

/// Why a form field is refused. The screen turns it into a translated text.
enum CourierFieldError {
  descriptionRequired,
  declaredValueRequired,
  invalidAmount,
  declaredValueNotPositive,
  declaredValueTooHigh,
  receiverLabelRequired,
}

@immutable
class CourierState {
  const CourierState({
    this.maxDeclaredValue = kColisFallbackMaxValue,
    this.deliveryMode = ColisDeliveryMode.code,
    this.forbiddenConfirmed = false,
    this.noCodeAccepted = false,
    this.pickupAddress,
    this.dropoffAddress,
    this.packageSize = PackageSize.petit,
    this.isLoadingLocation = false,
    this.isCalculatingPrice = false,
    this.isSubmitting = false,
    this.estimatedDistanceKm,
    this.estimatedPrice,
    this.loyaltyPreview,
    this.savedRecipients = const [],
    this.isLoadingSavedRecipients = false,
    this.saveRecipient = false,
    this.packagePhoto,
    this.isUploadingPhoto = false,
  });

  // ── Bon de prise en charge ────────────────────────────────────────────────

  /// Plafond lu en base, pour qu'un admin le change sans livrer une version.
  /// La valeur de repli ne sert qu'à l'affichage : le serveur revalide.
  final double maxDeclaredValue;

  final ColisDeliveryMode deliveryMode;

  /// L'expéditeur confirme que son colis ne contient rien d'interdit.
  final bool forbiddenConfirmed;

  /// En remise sans code, il accepte que photo et GPS tiennent lieu de preuve.
  final bool noCodeAccepted;

  final DeliveryAddress? pickupAddress;
  final DeliveryAddress? dropoffAddress;
  final PackageSize packageSize;

  final bool isLoadingLocation;
  final bool isCalculatingPrice;
  final bool isSubmitting;

  final double? estimatedDistanceKm;
  final double? estimatedPrice;

  // Preview only — the server's BEFORE INSERT trigger makes the real,
  // enforced determination at order creation.
  final LoyaltyMilestonePreview? loyaltyPreview;

  // Feature 2 — saved recipients
  final List<SavedRecipient> savedRecipients;
  final bool isLoadingSavedRecipients;
  final bool saveRecipient;

  // Feature 3 — package photo
  final File? packagePhoto;
  final bool isUploadingPhoto;

  /// [estimatedDistanceKm] and [packagePhoto] are getters so they can be set
  /// back to null.
  CourierState copyWith({
    double? maxDeclaredValue,
    ColisDeliveryMode? deliveryMode,
    bool? forbiddenConfirmed,
    bool? noCodeAccepted,
    DeliveryAddress? pickupAddress,
    DeliveryAddress? dropoffAddress,
    PackageSize? packageSize,
    bool? isLoadingLocation,
    bool? isCalculatingPrice,
    bool? isSubmitting,
    ValueGetter<double?>? estimatedDistanceKm,
    double? estimatedPrice,
    LoyaltyMilestonePreview? loyaltyPreview,
    List<SavedRecipient>? savedRecipients,
    bool? isLoadingSavedRecipients,
    bool? saveRecipient,
    ValueGetter<File?>? packagePhoto,
    bool? isUploadingPhoto,
  }) {
    return CourierState(
      maxDeclaredValue: maxDeclaredValue ?? this.maxDeclaredValue,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      forbiddenConfirmed: forbiddenConfirmed ?? this.forbiddenConfirmed,
      noCodeAccepted: noCodeAccepted ?? this.noCodeAccepted,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      packageSize: packageSize ?? this.packageSize,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isCalculatingPrice: isCalculatingPrice ?? this.isCalculatingPrice,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      estimatedDistanceKm: estimatedDistanceKm != null
          ? estimatedDistanceKm()
          : this.estimatedDistanceKm,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      loyaltyPreview: loyaltyPreview ?? this.loyaltyPreview,
      savedRecipients: savedRecipients ?? this.savedRecipients,
      isLoadingSavedRecipients:
          isLoadingSavedRecipients ?? this.isLoadingSavedRecipients,
      saveRecipient: saveRecipient ?? this.saveRecipient,
      packagePhoto: packagePhoto != null ? packagePhoto() : this.packagePhoto,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
    );
  }
}

/// Everything the Colis screen does besides drawing itself: the selection,
/// the price estimate, the saved recipients, the field rules, the photo
/// upload and the order creation.
class CourierController
    extends AutoDisposeFamilyNotifier<CourierState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  final _colisRepo = ColisRepository();
  final _recipientRepo = SavedRecipientRepository();
  final _photoStorage = PackagePhotoStorage();
  bool _disposed = false;

  @override
  CourierState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    // The GPS lookup and the saved recipients start from [start]; their
    // spinners show from the first frame, as before.
    return CourierState(
      isLoadingLocation: true,
      isLoadingSavedRecipients: _currentUserId != null,
    );
  }

  String? get _currentUserId => ref.read(authRepositoryProvider).currentUser?.uid;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Starts what the screen loads when it opens, in the same order as
  /// before. [currentLocationLabel] names the GPS pickup address; it is read
  /// once the position is known.
  void start({required String Function() currentLocationLabel}) {
    _setInitialPickupLocation(currentLocationLabel);
    _loadSavedRecipients();
    _loadLoyaltyPreview();
    _loadMaxDeclaredValue();
  }

  Future<void> _loadMaxDeclaredValue() async {
    final v = await _colisRepo.maxDeclaredValue();
    if (!_disposed) state = state.copyWith(maxDeclaredValue: v);
  }

  Future<void> _loadLoyaltyPreview() async {
    final preview = await predictNextOrderMilestone();
    if (!_disposed) state = state.copyWith(loyaltyPreview: preview);
  }

  Future<void> _loadSavedRecipients() async {
    final userId = _currentUserId;
    if (userId == null) return;
    // isLoadingSavedRecipients is already true: see build().
    try {
      final recipients = await _recipientRepo.getAll(userId);
      if (!_disposed) state = state.copyWith(savedRecipients: recipients);
    } catch (_) {
      // Non-fatal: feature degrades silently
    } finally {
      if (!_disposed) state = state.copyWith(isLoadingSavedRecipients: false);
    }
  }

  Future<void> _setInitialPickupLocation(
      String Function() currentLocationLabel) async {
    // isLoadingLocation is already true: see build().
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null && !_disposed) {
        final addressText = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (!_disposed) {
          state = state.copyWith(
            pickupAddress: DeliveryAddress(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              label: currentLocationLabel(),
              fullAddress: addressText,
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );
          _recalculatePrice();
        }
      }
    } catch (_) {
      // Non-fatal: user can select manually
    } finally {
      if (!_disposed) state = state.copyWith(isLoadingLocation: false);
    }
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void setPickupAddress(DeliveryAddress address) {
    state = state.copyWith(pickupAddress: address);
    _recalculatePrice();
  }

  void setDropoffAddress(DeliveryAddress address) {
    state = state.copyWith(dropoffAddress: address);
    _recalculatePrice();
  }

  /// Takes the saved recipient's delivery address, when it has one. The
  /// screen fills the name and phone fields itself.
  void applyRecipientAddress(SavedRecipient r) {
    if (r.deliveryAddress != null) {
      state = state.copyWith(dropoffAddress: r.deliveryAddress);
      _recalculatePrice();
    }
  }

  Future<void> deleteRecipient(String id) async {
    try {
      await _recipientRepo.delete(id);
      if (!_disposed) {
        state = state.copyWith(
          savedRecipients:
              state.savedRecipients.where((r) => r.id != id).toList(),
        );
      }
    } catch (_) {}
  }

  void setSaveRecipient(bool value) =>
      state = state.copyWith(saveRecipient: value);

  void setForbiddenConfirmed(bool value) =>
      state = state.copyWith(forbiddenConfirmed: value);

  void setDeliveryMode(ColisDeliveryMode mode) =>
      state = state.copyWith(deliveryMode: mode);

  void setNoCodeAccepted(bool value) =>
      state = state.copyWith(noCodeAccepted: value);

  void setPackagePhoto(File photo) =>
      state = state.copyWith(packagePhoto: () => photo);

  void removePackagePhoto() => state = state.copyWith(packagePhoto: () => null);

  void setPackageSize(PackageSize size) =>
      state = state.copyWith(packageSize: size);

  /// The first reason the parcel cannot be sent, or null. Call once the form
  /// fields are valid.
  CourierBlocker? blocker() {
    if (state.pickupAddress == null || state.dropoffAddress == null) {
      return CourierBlocker.missingAddresses;
    }

    // Les deux cases ne sont pas des champs de formulaire : un validator ne
    // les couvre pas, il faut les vérifier à la main.
    if (!state.forbiddenConfirmed) {
      return CourierBlocker.forbiddenNotConfirmed;
    }
    if (state.deliveryMode == ColisDeliveryMode.noCode &&
        !state.noCodeAccepted) {
      return CourierBlocker.photoProofNotAccepted;
    }

    if (_currentUserId == null) return CourierBlocker.notSignedIn;
    return null;
  }

  /// Uploads the optional photo, creates the parcel order and returns its
  /// id. Call only once the form is valid and [blocker] is null. Errors
  /// propagate; a failed photo upload or recipient save is not an error.
  ///
  /// [readFields] is called when the order is built, after the photo upload,
  /// and again when the recipient is saved: the values sent are the ones in
  /// the fields at that moment, as before. The selection is read at the same
  /// moments.
  Future<String> submit(CourierFields Function() readFields) async {
    final userId = _currentUserId!;
    state = state.copyWith(isSubmitting: true);

    try {
      // Upload photo first (if any) — non-blocking on failure
      final photoUrl = await _uploadPhoto(userId);

      final distanceKm = state.estimatedDistanceKm ??
          await tryDistanceKm(
            originLat: state.pickupAddress!.latitude,
            originLng: state.pickupAddress!.longitude,
            destLat: state.dropoffAddress!.latitude,
            destLng: state.dropoffAddress!.longitude,
          );
      final deliveryFee = calculateDeliveryFee(distanceKm: distanceKm);

      // Plus d'insertion directe dans `orders` : create_colis_order écrit la
      // commande ET sa déclaration dans la même transaction. Un colis part en
      // broadcast dès sa création ; il ne doit jamais exister sans valeur
      // déclarée ni mode de remise, sinon un livreur peut l'accepter sans rien
      // qui le protège. Le serveur revalide aussi le plafond : le contrôle du
      // formulaire est du confort, celui-là est la règle.
      final fields = readFields();
      final selection = state;
      final orderId = await _colisRepo.createOrder(
        pickupAddress: selection.pickupAddress!.toJson(),
        deliveryAddress: selection.dropoffAddress!.toJson(),
        senderPhone: fields.senderPhone.trim(),
        recipientPhone: fields.recipientPhone.trim(),
        packageSize: selection.packageSize.name,
        description: fields.description.trim(),
        declaredValue:
            double.parse(fields.declaredValue.trim().replaceAll(',', '.')),
        deliveryFee: deliveryFee,
        recipientName: fields.recipientName.trim().isEmpty
            ? null
            : fields.recipientName.trim(),
        mode: selection.deliveryMode,
        receiverLabel: selection.deliveryMode == ColisDeliveryMode.noCode
            ? fields.receiverLabel.trim()
            : null,
        packagePhotoUrl: photoUrl,
      );

      // Persist saved recipient (non-fatal if it fails)
      try {
        await _persistRecipient(userId, readFields());
      } catch (_) {}

      return orderId;
    } finally {
      if (!_disposed) state = state.copyWith(isSubmitting: false);
    }
  }

  // ── Field rules ───────────────────────────────────────────────────────────

  /// Le serveur revalide ce plafond. Ce validator évite juste à l'utilisateur
  /// de remplir tout le formulaire pour se faire refuser à la fin.
  CourierFieldError? validateDeclaredValue(String? v) {
    final raw = (v ?? '').trim().replaceAll(',', '.');
    if (raw.isEmpty) return CourierFieldError.declaredValueRequired;
    final value = double.tryParse(raw);
    if (value == null) return CourierFieldError.invalidAmount;
    if (value <= 0) return CourierFieldError.declaredValueNotPositive;
    if (value > state.maxDeclaredValue) {
      return CourierFieldError.declaredValueTooHigh;
    }
    return null;
  }

  CourierFieldError? validatePackageDescription(String? v) =>
      (v ?? '').trim().isEmpty ? CourierFieldError.descriptionRequired : null;

  CourierFieldError? validateReceiverLabel(String? v) {
    if (state.deliveryMode != ColisDeliveryMode.noCode) return null;
    return (v ?? '').trim().isEmpty
        ? CourierFieldError.receiverLabelRequired
        : null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _recalculatePrice() async {
    final pickup = state.pickupAddress;
    final dropoff = state.dropoffAddress;
    if (pickup == null || dropoff == null) return;
    state = state.copyWith(isCalculatingPrice: true);
    try {
      final distKm = await tryDistanceKm(
        originLat: pickup.latitude,
        originLng: pickup.longitude,
        destLat: dropoff.latitude,
        destLng: dropoff.longitude,
      );
      if (!_disposed) {
        state = state.copyWith(
          estimatedDistanceKm: () => distKm,
          estimatedPrice: calculateDeliveryFee(distanceKm: distKm),
        );
      }
    } catch (_) {
      // Keep previous estimate
    } finally {
      if (!_disposed) state = state.copyWith(isCalculatingPrice: false);
    }
  }

  Future<String?> _uploadPhoto(String userId) async {
    final photo = state.packagePhoto;
    if (photo == null) return null;
    state = state.copyWith(isUploadingPhoto: true);
    try {
      final bytes = await photo.readAsBytes();
      return await _photoStorage.uploadParcelPhoto(userId, bytes);
    } catch (_) {
      return null;
    } finally {
      if (!_disposed) state = state.copyWith(isUploadingPhoto: false);
    }
  }

  Future<void> _persistRecipient(String userId, CourierFields fields) async {
    if (!state.saveRecipient) return;
    final phone = fields.recipientPhone.trim();
    if (phone.isEmpty) return;
    await _recipientRepo.add(
      userId: userId,
      name: fields.recipientName.trim().isEmpty
          ? null
          : fields.recipientName.trim(),
      phone: phone,
      deliveryAddress: state.dropoffAddress?.toJson(),
    );
  }
}
