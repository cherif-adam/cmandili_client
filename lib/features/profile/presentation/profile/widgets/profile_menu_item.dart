import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// One white row of the profile tab:
///   (icon)  Title ................ trailing text  ›
class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final double screenWidth;
  final double screenHeight;

  /// Grey text on the right, e.g. the current language.
  final String? trailing;
  final Color? textColor;
  final Color? iconColor;
  final bool showArrow;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.screenWidth,
    required this.screenHeight,
    this.trailing,
    this.textColor,
    this.iconColor,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, screenHeight * 0.006),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.025),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppColors.primary,
                    size: screenWidth * 0.055,
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                      color: textColor ??
                          Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: TextStyle(
                      color: mutedColor?.withValues(alpha: 0.6),
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                if (showArrow) ...[
                  SizedBox(width: screenWidth * 0.02),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: screenWidth * 0.04,
                    color: mutedColor?.withValues(alpha: 0.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
