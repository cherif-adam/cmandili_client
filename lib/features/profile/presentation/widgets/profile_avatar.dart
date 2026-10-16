import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The customer's round picture in the profile header, with a soft white
/// ring and a green 📷 badge. Tap to pick a new one. While uploading: dimmed
/// with a spinner and no badge. No picture → a grey person icon.
class ProfileAvatar extends StatelessWidget {
  /// Null when the customer has no picture yet.
  final ImageProvider? image;
  final bool isUploading;
  final VoidCallback onTap;
  final double screenWidth;

  const ProfileAvatar({
    super.key,
    required this.image,
    required this.isUploading,
    required this.onTap,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final radius = screenWidth * 0.125;
    // The badge sits at the bottom-right edge of the circle.
    final badgeSize = screenWidth * 0.082;
    // The outer container adds a semi-transparent ring around the circle.
    final outerSize = radius * 2 + screenWidth * 0.04;

    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),

            // Avatar circle
            CircleAvatar(
              radius: radius,
              backgroundColor: Colors.white,
              backgroundImage: image,
              child: image != null
                  ? null
                  : Icon(Icons.person, size: radius, color: Colors.grey.shade400),
            ),

            // Upload in progress
            if (isUploading)
              Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),

            // Camera badge — hidden during upload.
            if (!isUploading)
              Positioned(
                bottom: screenWidth * 0.005,
                right: screenWidth * 0.005,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: badgeSize * 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
