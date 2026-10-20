import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/address.dart';

/// The customer's address book (table `user_addresses`). Every method lets
/// errors propagate: AddressNotifier decides what a failure means.
class AddressRepository {
  final _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// [userId]'s addresses, oldest first.
  Future<List<Address>> getAll(String userId) async {
    final response = await _supabase
        .from('user_addresses')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return (response as List).map((row) => Address(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      fullAddress: row['full_address'] as String? ?? '',
      isDefault: row['is_default'] as bool? ?? false,
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
    )).toList();
  }

  Future<void> add({
    required String id,
    required String userId,
    required String name,
    required String fullAddress,
    required bool isDefault,
    required double latitude,
    required double longitude,
  }) async {
    await _supabase.from('user_addresses').insert({
      'id': id,
      'user_id': userId,
      'name': name,
      'full_address': fullAddress,
      'is_default': isDefault,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<void> delete(String id) async {
    await _supabase.from('user_addresses').delete().eq('id', id);
  }

  /// Clears every default of [userId], then sets address [id] as the default.
  Future<void> setDefault(String userId, String id) async {
    await _supabase
        .from('user_addresses')
        .update({'is_default': false})
        .eq('user_id', userId);
    await _supabase
        .from('user_addresses')
        .update({'is_default': true})
        .eq('id', id);
  }
}
