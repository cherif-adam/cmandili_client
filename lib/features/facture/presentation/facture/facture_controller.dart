import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/package_photo_storage.dart';
import '../../../../core/utils/delivery_fee.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../bills/services/bill_reminder_service.dart';
import '../../../checkout/data/models/delivery_address.dart';
import '../../../loyalty/data/loyalty_eligibility.dart';
import '../../data/bill_type.dart';
import '../../data/facture_repository.dart';

final factureRepositoryProvider =
    Provider<FactureRepository>((ref) => FactureRepository());

/// One controller per facture screen on display. The argument is a key the
/// screen creates for itself: the home tab and the AI chat can each show a
/// facture form at the same time, and they must not share their selection.
/// Auto-disposed with the screen, like the State it replaces.
final factureControllerProvider = NotifierProvider.autoDispose
    .family<FactureController, FactureState, Object>(FactureController.new);

/// What is still missing before the form can be sent, in the order the
/// screen checks it.
enum FactureMissingInfo { billType, customerAddress, officeAddress }

/// Why a form field is refused. The screen turns it into a translated text.
enum FactureFieldError {
  referenceRequired,
  amountRequired,
  invalidAmount,
  phoneRequired,
  invalidPhone,
}

/// Thrown by [FactureController.submit] when nobody is signed in.
class FactureNotSignedInException implements Exception {
  const FactureNotSignedInException();
}

@immutable
class FactureState {
  const FactureState({
    this.billType,
    this.customerAddress,
    this.officeAddress,
    this.billPhoto,
    this.submitting = false,
    this.loyaltyPreview,
  });

  final BillType? billType;

  /// Pickup: where the driver collects the cash.
  final DeliveryAddress? customerAddress;

  /// Delivery: the office where the driver pays the bill.
  final DeliveryAddress? officeAddress;

  final File? billPhoto;
  final bool submitting;

  /// Preview only — the server's BEFORE INSERT trigger makes the real,
  /// enforced determination at order creation.
  final LoyaltyMilestonePreview? loyaltyPreview;

  /// [billPhoto] is a getter so the photo can be set back to null.
  FactureState copyWith({
    BillType? billType,
    DeliveryAddress? customerAddress,
    DeliveryAddress? officeAddress,
    ValueGetter<File?>? billPhoto,
    bool? submitting,
    LoyaltyMilestonePreview? loyaltyPreview,
  }) {
    return FactureState(
      billType: billType ?? this.billType,
      customerAddress: customerAddress ?? this.customerAddress,
      officeAddress: officeAddress ?? this.officeAddress,
      billPhoto: billPhoto != null ? billPhoto() : this.billPhoto,
      submitting: submitting ?? this.submitting,
      loyaltyPreview: loyaltyPreview ?? this.loyaltyPreview,
    );
  }
}

/// Everything the facture screen does besides drawing itself: the selection,
/// the field rules, the photo upload and the order creation.
class FactureController
    extends AutoDisposeFamilyNotifier<FactureState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  // Single source of truth for the flat rate — shared with supermarket
  // orders. Previously a second, independent hardcoded 5.000 that could
  // drift from kFlatDeliveryFee without anything noticing.
  static const serviceFee = kFlatDeliveryFee;
  static const _tunisianPhone = r'^\d{8}$';

  final _photoStorage = PackagePhotoStorage();
  bool _disposed = false;

  @override
  FactureState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    _loadLoyaltyPreview();
    return const FactureState();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadLoyaltyPreview() async {
    final preview = await predictNextOrderMilestone();
    if (!_disposed) state = state.copyWith(loyaltyPreview: preview);
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void selectBillType(BillType type) =>
      state = state.copyWith(billType: type);

  void setCustomerAddress(DeliveryAddress address) =>
      state = state.copyWith(customerAddress: address);

  void setOfficeAddress(DeliveryAddress address) =>
      state = state.copyWith(officeAddress: address);

  void setBillPhoto(File photo) =>
      state = state.copyWith(billPhoto: () => photo);

  void removeBillPhoto() => state = state.copyWith(billPhoto: () => null);

  /// The first choice still missing, or null when the form can be checked.
  FactureMissingInfo? missingInfo() {
    if (state.billType == null) return FactureMissingInfo.billType;
    if (state.customerAddress == null) {
      return FactureMissingInfo.customerAddress;
    }
    if (state.officeAddress == null) return FactureMissingInfo.officeAddress;
    return null;
  }

  /// Uploads the optional photo, creates the 'facture' order and returns its
  /// id. Call only once [missingInfo] is null and the form is valid.
  /// Throws [FactureNotSignedInException] when signed out; any other error
  /// propagates. A failed photo upload is not an error: the order is created
  /// without it.
  Future<String> submit({
    required String reference,
    required String amountText,
    required String phone,
  }) async {
    // Everything is read before the first await: the screen may be closed
    // while the photo uploads, and the order must still be created.
    final selection = state;
    final userId = ref.read(authRepositoryProvider).currentUser?.uid;
    final repository = ref.read(factureRepositoryProvider);

    state = state.copyWith(submitting: true);
    try {
      if (userId == null) throw const FactureNotSignedInException();

      final billPhotoUrl = await _uploadBillPhoto(userId, selection.billPhoto);
      final amount = double.tryParse(amountText.trim()) ?? 0.0;

      return await repository.createBillOrder(
        userId: userId,
        pickupAddress: selection.customerAddress!.toJson(),
        deliveryAddress: selection.officeAddress!.toJson(),
        billType: selection.billType!.dbValue,
        billReference: reference.trim(),
        billAmount: amount,
        billPhotoUrl: billPhotoUrl,
        senderPhone: phone.trim(),
        serviceFee: serviceFee,
      );
    } finally {
      if (!_disposed) state = state.copyWith(submitting: false);
    }
  }

  /// Schedules a reminder ~28 days from now for the same bill type.
  void scheduleReminder() {
    final type = state.billType!;
    BillReminderService.instance
        .scheduleReminder(billType: type.dbValue, billLabel: type.label)
        .catchError((_) {});
  }

  // ── Field rules ───────────────────────────────────────────────────────────

  FactureFieldError? validateReference(String? v) {
    if (v == null || v.trim().isEmpty) {
      return FactureFieldError.referenceRequired;
    }
    return null;
  }

  FactureFieldError? validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return FactureFieldError.amountRequired;
    final parsed = double.tryParse(v.trim());
    if (parsed == null || parsed <= 0) return FactureFieldError.invalidAmount;
    return null;
  }

  FactureFieldError? validatePhone(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return FactureFieldError.phoneRequired;
    if (!RegExp(_tunisianPhone).hasMatch(val)) {
      return FactureFieldError.invalidPhone;
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Public URL of the uploaded photo, or null when there is no photo or the
  /// upload failed (the order goes out without it, as before).
  Future<String?> _uploadBillPhoto(String userId, File? photo) async {
    if (photo == null) return null;
    try {
      final bytes = await photo.readAsBytes();
      return await _photoStorage.uploadBillPhoto(userId, bytes);
    } catch (e) {
      return null;
    }
  }
}
