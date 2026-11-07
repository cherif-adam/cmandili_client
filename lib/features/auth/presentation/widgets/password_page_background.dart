import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_system_bars.dart';

/// Background of the forgot / reset password screens: the login's orange
/// gradient (AppColors.brandBackgroundGradient) with two still white circles
/// (top right, bottom left). White system-bar icons wherever it shows.
class PasswordPageBackground extends StatelessWidget {
  const PasswordPageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemBars.onDark,
      child: Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.brandBackgroundGradient),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: -sh * 0.12,
          right: -sw * 0.2,
          child: _circle(sw * 0.6, Colors.white.withValues(alpha: 0.12)),
        ),
        Positioned(
          bottom: -sh * 0.08,
          left: -sw * 0.15,
          child: _circle(sw * 0.5, Colors.white.withValues(alpha: 0.10)),
        ),
      ],
      ),
    );
  }

  static Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
