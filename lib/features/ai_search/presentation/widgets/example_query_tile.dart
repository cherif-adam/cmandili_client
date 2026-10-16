import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A white tappable row with an emoji and an example query in italics
/// (or, for the photo option, purple bold text and a camera icon).
class ExampleQueryTile extends StatelessWidget {
  final String emoji;
  final String text;
  final VoidCallback onTap;
  final bool isImageOption;

  const ExampleQueryTile({
    super.key,
    required this.emoji,
    required this.text,
    required this.onTap,
    this.isImageOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isImageOption
                ? const Color(0xFF6C3DE1).withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isImageOption
                      ? const Color(0xFF6C3DE1)
                      : AppColors.textSecondary,
                  fontStyle: isImageOption
                      ? FontStyle.normal
                      : FontStyle.italic,
                  fontWeight:
                      isImageOption ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              isImageOption
                  ? Icons.camera_alt_rounded
                  : Icons.north_west_rounded,
              size: 16,
              color: const Color(0xFF6C3DE1).withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
