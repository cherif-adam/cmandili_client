import 'package:flutter/material.dart';

import '../chat_palette.dart';

// ─── Starter suggestion chip (empty-state only) ─────────────────────────────

class ChatSuggestionChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const ChatSuggestionChip({super.key, required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kChatOrange.withValues(alpha: 0.3)),
            boxShadow: const [BoxShadow(color: kChatAiBubbleShadow, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kChatTextDark)),
            ],
          ),
        ),
      ),
    );
  }
}
