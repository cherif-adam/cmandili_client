import 'package:flutter/material.dart';

/// The green gradient behind the login screen.
class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF059669),
            Color(0xFF0D9488),
            Color(0xFF0F766E),
          ],
        ),
      ),
    );
  }
}

/// Three soft white circles drifting slowly over the gradient.
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
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A circle fading from white 15 % in the middle to 5 % at the edge.
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
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
      ),
    );
  }
}
