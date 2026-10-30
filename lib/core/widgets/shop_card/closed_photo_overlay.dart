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

  /// The photo's own corners. Defaults to a shop card's rounded top.
  final BorderRadius? borderRadius;

  const ClosedPhotoOverlay({
    super.key,
    required this.label,
    required this.screenWidth,
    required this.screenHeight,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: borderRadius ??
            BorderRadius.only(
              topLeft: Radius.circular(screenWidth * 0.06),
              topRight: Radius.circular(screenWidth * 0.06),
            ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          // Shrinks the label on a photo narrower than it (the AI search
          // thumbnail); on a shop card's photo it already fits and is left as is.
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
      ),
    );
  }
}
