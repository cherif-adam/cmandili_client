import 'package:flutter/material.dart';

// ─── AI CircleAvatar ───────────────────────────────────────────────────────────

class ChatAiAvatar extends StatelessWidget {
  const ChatAiAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF9800).withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
      ),
    );
  }
}
