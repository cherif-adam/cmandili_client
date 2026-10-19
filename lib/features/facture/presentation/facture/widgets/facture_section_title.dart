import 'package:flutter/material.dart';

import 'facture_colors.dart';

/// A bold section title of the "Facture" page ("Type de facture",
/// "Détails de la facture"…).
class FactureSectionTitle extends StatelessWidget {
  final String text;

  const FactureSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: kFactureTextDark,
      ),
    );
  }
}
