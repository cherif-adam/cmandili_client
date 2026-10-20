import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/colis_repository.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // L'ordre n'est pas neutre : le mode recommandé est aussi celui par
        // défaut (_deliveryMode) et passe donc en premier.
        _ModeOption(
          selected: mode == ColisDeliveryMode.code,
          onTap: () => onModeChanged(ColisDeliveryMode.code),
          title: l10n.colisModeCodeTitle,
          subtitle: l10n.colisModeCodeSubtitle,
          icon: Icons.lock_outline,
          badge: l10n.colisModeRecommended,
          screenWidth: w,
          screenHeight: h,
        ),
        _ModeOption(
          selected: mode == ColisDeliveryMode.noCode,
          onTap: () => onModeChanged(ColisDeliveryMode.noCode),
          title: l10n.colisModeNoCodeTitle,
          subtitle: l10n.colisModeNoCodeSubtitle,
          icon: Icons.handshake_outlined,
          screenWidth: w,
          screenHeight: h,
        ),
        if (mode == ColisDeliveryMode.noCode) ...[
          SizedBox(height: h * 0.004),
          CourierTextField(
            controller: receiverLabelController,
            hint: l10n.courierReceiverLabelExample,
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
              l10n.courierAcceptPhotoProofCheckbox,
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
  final String? badge;
  final double screenWidth;
  final double screenHeight;

  const _ModeOption({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
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
                  Row(
                    children: [
                      // Flexible : à l'étroit, c'est le titre qui se coupe,
                      // jamais le badge — un « Recommandé » tronqué en
                      // « Recomm… » n'aide personne.
                      Flexible(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: w * 0.038,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: w * 0.02),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: w * 0.02, vertical: h * 0.003),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                                fontSize: w * 0.028,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
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
