import 'package:flutter/material.dart';

// ─── Service pill ──────────────────────────────────────────────────────────────

class ChatServicePill extends StatelessWidget {
  final String emoji;
  final String label;
  /// Narrow screens: keep the emoji, drop the label, so the title column keeps
  /// enough room for the longest status text.
  final bool compact;
  const ChatServicePill({super.key, required this.emoji, required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
