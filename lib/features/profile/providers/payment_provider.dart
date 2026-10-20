import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/payment_method.dart';
import '../data/payment_method_repository.dart';

export '../data/models/payment_method.dart';

/// The payment-methods screen's controller: the saved cards, adding,
/// deleting and choosing the default. Talks to PaymentMethodRepository.
class PaymentNotifier extends StateNotifier<List<PaymentMethod>> {
  final _repository = PaymentMethodRepository();

  PaymentNotifier() : super([]) {
    _load();
  }

  /// The "Enregistrer" rule of the add-card dialog: a name and at least 4
  /// digits (the last 4 are what gets stored).
  static bool canAddCard(String cardHolderName, String cardNumber) =>
      cardHolderName.isNotEmpty && cardNumber.length >= 4;

  Future<void> _load() async {
    final userId = _repository.currentUserId;
    if (userId == null) return;
    try {
      state = await _repository.getAll(userId);
    } catch (_) {}
  }

  // Only the last 4 digits and expiry are stored. Never store full PAN — PCI compliance.
  Future<void> addCard(String cardHolderName, String cardNumber, String expiryDate) async {
    final userId = _repository.currentUserId;
    final id = const Uuid().v4();
    final last4 = cardNumber.length >= 4
        ? cardNumber.substring(cardNumber.length - 4)
        : 'xxxx';
    final isFirst = state.isEmpty;

    if (userId != null) {
      try {
        await _repository.add(
          id: id,
          userId: userId,
          cardHolderName: cardHolderName,
          lastFour: last4,
          expiryDate: expiryDate,
          isDefault: isFirst,
        );
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
      await _repository.delete(id);
    } catch (_) {}
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> setDefault(String id) async {
    final userId = _repository.currentUserId;
    if (userId != null) {
      try {
        await _repository.setDefault(userId, id);
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
