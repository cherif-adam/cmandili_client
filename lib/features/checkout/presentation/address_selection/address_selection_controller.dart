import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/location_service.dart';
import '../../../profile/providers/address_provider.dart';
import '../../data/models/delivery_address.dart';

/// One controller per address picker on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces. Its state is "the current location is being read".
final addressSelectionControllerProvider = NotifierProvider.autoDispose
    .family<AddressSelectionController, bool, Object>(
        AddressSelectionController.new);

/// The customer's address book, as delivery addresses.
final savedDeliveryAddressesProvider = Provider.autoDispose<List<DeliveryAddress>>((ref) {
  return [
    for (final saved in ref.watch(addressProvider))
      DeliveryAddress(
        id: saved.id,
        label: saved.name,
        fullAddress: saved.fullAddress,
        latitude: saved.latitude,
        longitude: saved.longitude,
        isDefault: saved.isDefault,
      ),
  ];
});

class AddressSelectionController extends AutoDisposeFamilyNotifier<bool, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  bool build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Reads the GPS position and its street address, labelled [label].
  /// Returns null when no position could be read; other failures throw.
  Future<DeliveryAddress?> locate({required String label}) async {
    state = true;
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) return null;

      final address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      return DeliveryAddress(
        id: const Uuid().v4(),
        label: label,
        fullAddress: address,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } finally {
      if (!_disposed) state = false;
    }
  }

  /// Saves an address the customer just placed on the map.
  void save(DeliveryAddress address) {
    // Pass through the coordinates the sheet already has — avoids a second
    // geocode call and, more importantly, avoids the notifier's own
    // hardcoded-placeholder fallback for this address.
    ref.read(addressProvider.notifier).addAddress(
          address.label,
          address.fullAddress,
          latitude: address.latitude,
          longitude: address.longitude,
        );
  }
}
