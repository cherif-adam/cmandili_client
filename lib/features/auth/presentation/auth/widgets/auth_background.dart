import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_system_bars.dart';

/// The orange gradient behind the login screen (deep orange at the top,
/// warming to the splash orange): see AppColors.brandBackgroundGradient.
/// White system-bar icons wherever it shows.
class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemBars.onDark,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.brandBackgroundGradient),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// Three soft circles drifting slowly over the gradient: a warm amber glow,
/// the splash's second colour, fading to white at the edge.
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
              top: -screenHeight * 0.15,
              right: -screenWidth * 0.2 + (animation.value * screenWidth * 0.1),
              child: _Circle(size: screenWidth * 0.6),
            ),
            Positioned(
              bottom: -screenHeight * 0.1,
              left: -screenWidth * 0.15 - (animation.value * screenWidth * 0.1),
              child: _Circle(size: screenWidth * 0.5),
            ),
            Positioned(
              top: screenHeight * 0.3,
              left: -screenWidth * 0.1,
              child: Container(
                width: screenWidth * 0.3,
                height: screenWidth * 0.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.splashAmber.withValues(alpha: 0.14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A circle glowing warm amber in the middle, fading to a faint white edge.
class _Circle extends StatelessWidget {
  final double size;

  const _Circle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.splashAmber.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
      ),
    );
  }
}
