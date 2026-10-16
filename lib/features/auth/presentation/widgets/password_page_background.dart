import 'package:flutter/material.dart';

/// Background of the forgot / reset password screens: the login green
/// gradient with two still white circles (top right, bottom left).
class PasswordPageBackground extends StatelessWidget {
  const PasswordPageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF0F766E)],
            ),
          ),
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
    );
  }

  static Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
