import 'package:flutter/material.dart';

/// A small rounded badge over a shop's photo ("25 min · 640 m", "Nouveau",
/// "Pizza", "★ 4.6 (214)"), with a light shadow.
///
/// Place it inside a [Positioned] in the photo's [Stack].
class PhotoPill extends StatelessWidget {
  final Color color;
  final Widget child;
  final double screenWidth;
  final double screenHeight;

  const PhotoPill({
    super.key,
    required this.color,
    required this.child,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenHeight * 0.008,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: screenWidth * 0.01,
            offset: Offset(0, screenHeight * 0.0025),
          ),
        ],
      ),
      child: child,
    );
  }
}
