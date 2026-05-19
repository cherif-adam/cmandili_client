import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class Address {
  final String id;
  final String name; // Home, Work, etc.
  final String fullAddress;
  final bool isDefault;

  Address({
    required this.id,
    required this.name,
    required this.fullAddress,
    this.isDefault = false,
  });

  Address copyWith({
    String? id,
    String? name,
    String? fullAddress,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      fullAddress: fullAddress ?? this.fullAddress,
      isDefault: isDefault ?? this.isDefault,
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
      )).toList();
    } catch (_) {
      // Keep empty list on error — user can add manually
    }
  }

  Future<void> addAddress(String name, String fullAddress) async {
    final userId = _supabase.auth.currentUser?.id;
    final id = const Uuid().v4();
    final isFirst = state.isEmpty;

    if (userId != null) {
      try {
        await _supabase.from('user_addresses').insert({
          'id': id,
          'user_id': userId,
          'name': name,
          'full_address': fullAddress,
          'is_default': isFirst,
        });
      } catch (_) {}
    }

    state = [
      ...state,
      Address(id: id, name: name, fullAddress: fullAddress, isDefault: isFirst),
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
