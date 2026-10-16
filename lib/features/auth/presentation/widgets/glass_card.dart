import 'dart:ui';

import 'package:flutter/material.dart';

/// The frosted white card holding the login form (blurs what is behind it).
class GlassCard extends StatelessWidget {
  final Widget child;
  final double screenWidth;
  final double screenHeight;

  const GlassCard({
    super.key,
    required this.child,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(screenWidth * 0.08),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.06),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(screenWidth * 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: screenWidth * 0.08,
                offset: Offset(0, screenHeight * 0.015),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
