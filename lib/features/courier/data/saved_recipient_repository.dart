import 'package:supabase_flutter/supabase_flutter.dart';

import 'saved_recipient.dart';

/// The recipients a customer saved from earlier parcels
/// (table `saved_recipients`). Every method lets errors propagate: the
/// courier screen decides which failures are silent.
class SavedRecipientRepository {
  final _supabase = Supabase.instance.client;

  /// [userId]'s saved recipients, newest first.
  Future<List<SavedRecipient>> getAll(String userId) async {
    final rows = await _supabase
        .from('saved_recipients')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SavedRecipient.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete(String id) async {
    await _supabase.from('saved_recipients').delete().eq('id', id);
  }

  Future<void> add({
    required String userId,
    String? name,
    required String phone,
    Map<String, dynamic>? deliveryAddress,
  }) async {
    await _supabase.from('saved_recipients').insert({
      'user_id': userId,
      'name': name,
      'phone': phone,
      'delivery_address': deliveryAddress,
    });
  }
}
