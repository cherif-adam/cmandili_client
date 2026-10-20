import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// A bold section title of the checkout ("Adresse de livraison",
/// "Moyen de paiement"…).
class CheckoutSectionTitle extends StatelessWidget {
  final String text;

  const CheckoutSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
