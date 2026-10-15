import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_customization.dart';

/// Two-tab switch: "Écrire un message" / "Message vocal". The selected
/// tab is filled green.
class CustomizationTypeSelector extends StatelessWidget {
  final CustomizationType selectedType;
  final ValueChanged<CustomizationType> onChanged;
  final double screenWidth;

  const CustomizationTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.01),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: AppLocalizations.of(context)!.typeMessage,
              icon: Icons.edit_outlined,
              isSelected: selectedType == CustomizationType.text,
              onTap: () => onChanged(CustomizationType.text),
              screenWidth: screenWidth,
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _TypeButton(
              label: AppLocalizations.of(context)!.voiceMessage,
              icon: Icons.mic_outlined,
              isSelected: selectedType == CustomizationType.voice,
              onTap: () => onChanged(CustomizationType.voice),
              screenWidth: screenWidth,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab: icon + label.
class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double screenWidth;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.03,
          horizontal: screenWidth * 0.02,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(screenWidth * 0.025),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
              size: screenWidth * 0.05,
            ),
            SizedBox(width: screenWidth * 0.02),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: screenWidth * 0.035,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
