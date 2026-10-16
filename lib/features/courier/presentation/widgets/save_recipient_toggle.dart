import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'courier_colors.dart';

/// The row with a bookmark icon and a switch: "Enregistrer ce destinataire
/// pour la prochaine fois". The whole row is tappable.
class SaveRecipientToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double screenWidth;
  final double screenHeight;

  const SaveRecipientToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return Padding(
      padding: EdgeInsets.only(top: h * 0.01),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.012,
          ),
          decoration: BoxDecoration(
            color: value
                ? kCourierPurple.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? kCourierPurple.withValues(alpha: 0.4)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                value
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: value ? kCourierPurple : AppColors.textSecondary,
                size: w * 0.055,
              ),
              SizedBox(width: w * 0.03),
              Expanded(
                child: Text(
                  'Enregistrer ce destinataire pour la prochaine fois',
                  style: TextStyle(
                    fontSize: w * 0.036,
                    fontWeight:
                        value ? FontWeight.w600 : FontWeight.normal,
                    color: value ? kCourierPurple : AppColors.textSecondary,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: (v) => onChanged(v),
                activeColor: kCourierPurple,
                activeTrackColor: kCourierPurple.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
