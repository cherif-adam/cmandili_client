import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/payment_method.dart';

/// The customer's saved cards (table `payment_methods`). Every method lets
/// errors propagate: PaymentNotifier decides what a failure means.
class PaymentMethodRepository {
  final _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// [userId]'s cards, oldest first.
  Future<List<PaymentMethod>> getAll(String userId) async {
    final rows = await _supabase
        .from('payment_methods')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return (rows as List).map((row) => PaymentMethod(
          id: row['id'] as String,
          cardHolderName: row['card_holder_name'] as String? ?? '',
          lastFourDigits: row['last_four'] as String? ?? 'xxxx',
          expiryDate: row['expiry_date'] as String? ?? '',
          isDefault: row['is_default'] as bool? ?? false,
        )).toList();
  }

  Future<void> add({
    required String id,
    required String userId,
    required String cardHolderName,
    required String lastFour,
    required String expiryDate,
    required bool isDefault,
  }) async {
    await _supabase.from('payment_methods').insert({
      'id': id,
      'user_id': userId,
      'card_holder_name': cardHolderName,
      'last_four': lastFour,
      'expiry_date': expiryDate,
      'is_default': isDefault,
    });
  }

  Future<void> delete(String id) async {
    await _supabase.from('payment_methods').delete().eq('id', id);
  }

  /// Clears every default of [userId], then sets card [id] as the default.
  Future<void> setDefault(String userId, String id) async {
    await _supabase
        .from('payment_methods')
        .update({'is_default': false})
        .eq('user_id', userId);
    await _supabase
        .from('payment_methods')
        .update({'is_default': true})
        .eq('id', id);
  }
}
