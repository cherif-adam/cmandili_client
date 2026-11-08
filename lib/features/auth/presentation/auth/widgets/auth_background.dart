import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_system_bars.dart';

/// The soft light background behind the login screen: pure white at the top
/// (the logo image has a white background, so it blends in), warming to a
/// gentle peach at the bottom. Easy on the eyes; dark system-bar icons.
class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemBars.onLight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFFFFBF7),
              Color(0xFFFFEEDD),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// Two very faint orange glows drifting slowly in the corners.
class AuthFloatingCircles extends StatelessWidget {
  /// 0 → 1, repeating (one loop every 20 s).
  final Animation<double> animation;
  final double screenWidth;
  final double screenHeight;

  const AuthFloatingCircles({
    super.key,
    required this.animation,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -screenHeight * 0.12,
              right: -screenWidth * 0.25 + (animation.value * screenWidth * 0.08),
              child: _Glow(size: screenWidth * 0.7),
            ),
            Positioned(
              bottom: -screenHeight * 0.1,
              left: -screenWidth * 0.25 - (animation.value * screenWidth * 0.08),
              child: _Glow(size: screenWidth * 0.75),
            ),
          ],
        );
      },
    );
  }
}

/// A circle glowing faintly orange in the middle, fading to nothing.
class _Glow extends StatelessWidget {
  final double size;

  const _Glow({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.splashAmber.withValues(alpha: 0.16),
            AppColors.splashAmber.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
