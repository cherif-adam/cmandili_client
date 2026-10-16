import 'package:flutter/material.dart';

/// Darkens a closed shop's photo and shows "🔒 Fermé" in the middle.
/// Closed shops stay tappable — browsing is allowed, ordering is blocked
/// on the shop's page.
///
/// Returns a [Positioned.fill], so it must be a direct child of the photo's
/// [Stack].
class ClosedPhotoOverlay extends StatelessWidget {
  final String label;
  final double screenWidth;
  final double screenHeight;

  const ClosedPhotoOverlay({
    super.key,
    required this.label,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(screenWidth * 0.06),
          topRight: Radius.circular(screenWidth * 0.06),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.01,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(screenWidth * 0.06),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: screenWidth * 0.04,
                  color: Colors.white,
                ),
                SizedBox(width: screenWidth * 0.015),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
