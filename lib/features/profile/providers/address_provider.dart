import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class Address {
  final String id;
  final String name; // Home, Work, etc.
  final String fullAddress;
  final bool isDefault;
  final double latitude;
  final double longitude;

  Address({
    required this.id,
    required this.name,
    required this.fullAddress,
    this.isDefault = false,
    this.latitude = 0,
    this.longitude = 0,
  });

  Address copyWith({
    String? id,
    String? name,
    String? fullAddress,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      fullAddress: fullAddress ?? this.fullAddress,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class AddressNotifier extends StateNotifier<List<Address>> {
  final _supabase = Supabase.instance.client;

  AddressNotifier() : super([]) {
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await _supabase
          .from('user_addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      state = (response as List).map((row) => Address(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        fullAddress: row['full_address'] as String? ?? '',
        isDefault: row['is_default'] as bool? ?? false,
        latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      )).toList();
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
    final userId = _supabase.auth.currentUser?.id;
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
        await _supabase.from('user_addresses').insert({
          'id': id,
          'user_id': userId,
          'name': name,
          'full_address': fullAddress,
          'is_default': isFirst,
          'latitude': lat,
          'longitude': lng,
        });
      } catch (_) {}
    }

    state = [
      ...state,
      Address(id: id, name: name, fullAddress: fullAddress, isDefault: isFirst, latitude: lat, longitude: lng),
    ];
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _supabase.from('user_addresses').delete().eq('id', id);
    } catch (_) {}
    state = state.where((a) => a.id != id).toList();
  }

  Future<void> setDefault(String id) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase
            .from('user_addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
        await _supabase
            .from('user_addresses')
            .update({'is_default': true})
            .eq('id', id);
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
