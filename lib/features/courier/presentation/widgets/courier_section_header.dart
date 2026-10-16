import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'courier_colors.dart';

/// A section title of the "Colis" page: purple icon + bold title.
class CourierSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final double screenWidth;

  const CourierSectionHeader(
    this.title,
    this.icon, {
    super.key,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    return Row(
      children: [
        Icon(icon, color: kCourierPurple, size: w * 0.055),
        SizedBox(width: w * 0.02),
        // Expanded, sinon le titre pousse la Row au-delà de l'écran : sans
        // contrainte il se dessine à sa largeur naturelle. Plusieurs en-têtes
        // de cette page débordaient déjà de 37 à 48 px ; « Comment le livreur
        // remet votre colis ? » est plus long et portait le débordement à
        // plus de 250 px. Contraint, le titre passe simplement à la ligne.
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: w * 0.042,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
