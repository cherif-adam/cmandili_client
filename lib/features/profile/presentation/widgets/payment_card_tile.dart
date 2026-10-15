import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/payment_provider.dart';

/// A saved card drawn like a bank card:
///   💳 ....................... DEFAULT
///   **** **** **** 1234
///   HOLDER NAME ............... 12/28
/// Swipe left (red background) to delete it.
class PaymentCardTile extends StatelessWidget {
  final PaymentMethod card;

  /// Dark grey card when true, green-to-orange when false.
  final bool dark;
  final VoidCallback onDelete;

  const PaymentCardTile({
    super.key,
    required this.card,
    required this.dark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(card.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)]
                : [AppColors.primary, Colors.orangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.credit_card, color: Colors.white),
                Text(
                  card.isDefault ? 'DEFAULT' : '',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '**** **** **** ${card.lastFourDigits}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.cardHolderName.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  card.expiryDate,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
