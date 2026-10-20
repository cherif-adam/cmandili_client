import 'package:flutter/material.dart';

import '../../../data/saved_recipient.dart';
import 'courier_colors.dart';

/// A purple pill with a saved recipient's name. Tap fills the form; long
/// press or the small × asks to delete it.
class SavedRecipientChip extends StatelessWidget {
  final SavedRecipient recipient;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final double screenWidth;
  final double screenHeight;

  const SavedRecipientChip({
    super.key,
    required this.recipient,
    required this.onTap,
    required this.onDelete,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.035,
          vertical: h * 0.006,
        ),
        decoration: BoxDecoration(
          color: kCourierPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: kCourierPurple.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: w * 0.04, color: kCourierPurple),
            SizedBox(width: w * 0.01),
            Text(
              recipient.displayLabel,
              style: TextStyle(
                color: kCourierPurple,
                fontSize: w * 0.033,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: w * 0.015),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                size: w * 0.038,
                color: kCourierPurple.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
