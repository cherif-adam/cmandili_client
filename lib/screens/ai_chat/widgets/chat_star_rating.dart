import 'package:flutter/material.dart';

import '../chat_palette.dart';

// ─── Star rating ───────────────────────────────────────────────────────────────

class ChatStarRating extends StatelessWidget {
  final double rating;
  const ChatStarRating({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kChatTextMid)),
      ],
    );
  }
}
