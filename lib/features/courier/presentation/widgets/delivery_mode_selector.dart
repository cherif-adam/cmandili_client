import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/colis_repository.dart';
import 'courier_text_field.dart';

/// "Remise au destinataire": two choices — "Avec code" or "Remise sans
/// code". With "sans code" a "remis à…" field and an acceptance checkbox
/// appear under them.
class DeliveryModeSelector extends StatelessWidget {
  final ColisDeliveryMode mode;
  final ValueChanged<ColisDeliveryMode> onModeChanged;
  final TextEditingController receiverLabelController;
  final FormFieldValidator<String> receiverLabelValidator;
  final bool noCodeAccepted;
  final ValueChanged<bool> onNoCodeAcceptedChanged;
  final double screenWidth;
  final double screenHeight;

  const DeliveryModeSelector({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.receiverLabelController,
    required this.receiverLabelValidator,
    required this.noCodeAccepted,
    required this.onNoCodeAcceptedChanged,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return Column(
      children: [
        _ModeOption(
          selected: mode == ColisDeliveryMode.code,
          onTap: () => onModeChanged(ColisDeliveryMode.code),
          title: 'Avec code',
          subtitle:
              'Un code à 4 chiffres vous sera donné. Le destinataire le '
              'communique au livreur à la remise.',
          icon: Icons.pin_outlined,
          screenWidth: w,
          screenHeight: h,
        ),
        _ModeOption(
          selected: mode == ColisDeliveryMode.noCode,
          onTap: () => onModeChanged(ColisDeliveryMode.noCode),
          title: 'Remise sans code',
          subtitle:
              "Quand le destinataire n'a pas de téléphone — un enfant à "
              "l'école, un gardien. La preuve sera la photo et la position.",
          icon: Icons.handshake_outlined,
          screenWidth: w,
          screenHeight: h,
        ),
        if (mode == ColisDeliveryMode.noCode) ...[
          SizedBox(height: h * 0.004),
          CourierTextField(
            controller: receiverLabelController,
            hint: "Ex : Gardien de l'école, voisin du 3e…",
            icon: Icons.person_pin_circle_outlined,
            screenWidth: w,
            validator: receiverLabelValidator,
          ),
          CheckboxListTile(
            value: noCodeAccepted,
            onChanged: (v) => onNoCodeAcceptedChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: Text(
              "J'accepte que la preuve de remise soit la photo et la position "
              'du livreur.',
              style: TextStyle(fontSize: w * 0.034),
            ),
          ),
        ],
      ],
    );
  }
}

/// One choice card: icon, bold title, grey explanation, and a green check
/// when selected.
class _ModeOption extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final double screenWidth;
  final double screenHeight;

  const _ModeOption({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(w * 0.035),
        margin: EdgeInsets.only(bottom: h * 0.012),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: w * 0.055),
            SizedBox(width: w * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: w * 0.038,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: h * 0.004),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: w * 0.031,
                          color: AppColors.textSecondary,
                          height: 1.3)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: AppColors.primary, size: w * 0.05),
          ],
        ),
      ),
    );
  }
}
