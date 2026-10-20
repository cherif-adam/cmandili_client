import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';

import '../data/address_repository.dart';
import '../data/models/address.dart';

export '../data/models/address.dart';

/// The address book's controller (saved-addresses screen, checkout's
/// address picker): the addresses, adding (with geocoding when needed),
/// deleting and choosing the default. Talks to AddressRepository.
class AddressNotifier extends StateNotifier<List<Address>> {
  final _repository = AddressRepository();

  AddressNotifier() : super([]) {
    _loadAddresses();
  }

  /// The "Enregistrer" rule of the add-address dialog: a name is required.
  static bool canSaveAddress(String name) => name.isNotEmpty;

  Future<void> _loadAddresses() async {
    final userId = _repository.currentUserId;
    if (userId == null) return;
    try {
      state = await _repository.getAll(userId);
    } catch (_) {
      // Keep empty list on error — user can add manually
    }
  }

  /// [latitude]/[longitude] let a caller that already geocoded the address
  /// (e.g. the checkout add-address sheet) pass the real coordinates through
  /// instead of paying for a second geocode. When omitted (the plain
  /// saved-addresses screen has no map/geocoding step of its own), this
  /// geocodes [fullAddress] itself so every saved row still gets a real
  /// coordinate — previously this was never geocoded at all here, and every
  /// saved address was served back to checkout with a hardcoded Tunis-area
  /// placeholder (36.8065, 10.1815) regardless of its real location, which
  /// then became the delivery-address pin rendered on the tracking map.
  Future<void> addAddress(
    String name,
    String fullAddress, {
    double? latitude,
    double? longitude,
  }) async {
    final userId = _repository.currentUserId;
    final id = const Uuid().v4();
    final isFirst = state.isEmpty;

    double lat = latitude ?? 0;
    double lng = longitude ?? 0;
    if (latitude == null || longitude == null) {
      try {
        final locations = await locationFromAddress(fullAddress);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (_) {
        // Keep 0,0 — better an obviously-unset coordinate than a silently
        // wrong placeholder pinned somewhere real on the map.
      }
    }

    if (userId != null) {
      try {
        await _repository.add(
          id: id,
          userId: userId,
          name: name,
          fullAddress: fullAddress,
          isDefault: isFirst,
          latitude: lat,
          longitude: lng,
        );
      } catch (_) {}
    }

    state = [
      ...state,
      Address(id: id, name: name, fullAddress: fullAddress, isDefault: isFirst, latitude: lat, longitude: lng),
    ];
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _repository.delete(id);
    } catch (_) {}
    state = state.where((a) => a.id != id).toList();
  }

  Future<void> setDefault(String id) async {
    final userId = _repository.currentUserId;
    if (userId != null) {
      try {
        await _repository.setDefault(userId, id);
      } catch (_) {}
    }
    state = [
      for (final address in state)
        if (address.id == id)
          address.copyWith(isDefault: true)
        else
          address.copyWith(isDefault: false)
    ];
  }
}

final addressProvider = StateNotifierProvider<AddressNotifier, List<Address>>((ref) {
  return AddressNotifier();
});
