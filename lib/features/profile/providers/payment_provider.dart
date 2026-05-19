import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PaymentMethod {
  final String id;
  final String cardHolderName;
  final String lastFourDigits;
  final String expiryDate;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.cardHolderName,
    required this.lastFourDigits,
    required this.expiryDate,
    this.isDefault = false,
  });

  PaymentMethod copyWith({
    String? id,
    String? cardHolderName,
    String? lastFourDigits,
    String? expiryDate,
    bool? isDefault,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      expiryDate: expiryDate ?? this.expiryDate,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class PaymentNotifier extends StateNotifier<List<PaymentMethod>> {
  final _supabase = Supabase.instance.client;

  PaymentNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await _supabase
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      state = (rows as List).map((row) => PaymentMethod(
            id: row['id'] as String,
            cardHolderName: row['card_holder_name'] as String? ?? '',
            lastFourDigits: row['last_four'] as String? ?? 'xxxx',
            expiryDate: row['expiry_date'] as String? ?? '',
            isDefault: row['is_default'] as bool? ?? false,
          )).toList();
    } catch (_) {}
  }

  // Only the last 4 digits and expiry are stored. Never store full PAN — PCI compliance.
  Future<void> addCard(String cardHolderName, String cardNumber, String expiryDate) async {
    final userId = _supabase.auth.currentUser?.id;
    final id = const Uuid().v4();
    final last4 = cardNumber.length >= 4
        ? cardNumber.substring(cardNumber.length - 4)
        : 'xxxx';
    final isFirst = state.isEmpty;

    if (userId != null) {
      try {
        await _supabase.from('payment_methods').insert({
          'id': id,
          'user_id': userId,
          'card_holder_name': cardHolderName,
          'last_four': last4,
          'expiry_date': expiryDate,
          'is_default': isFirst,
        });
      } catch (_) {}
    }

    state = [
      ...state,
      PaymentMethod(
        id: id,
        cardHolderName: cardHolderName,
        lastFourDigits: last4,
        expiryDate: expiryDate,
        isDefault: isFirst,
      ),
    ];
  }

  Future<void> deleteCard(String id) async {
    try {
      await _supabase.from('payment_methods').delete().eq('id', id);
    } catch (_) {}
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> setDefault(String id) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase
            .from('payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId);
        await _supabase
            .from('payment_methods')
            .update({'is_default': true})
            .eq('id', id);
      } catch (_) {}
    }
    state = [
      for (final card in state)
        card.copyWith(isDefault: card.id == id),
    ];
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, List<PaymentMethod>>((ref) {
  return PaymentNotifier();
});
