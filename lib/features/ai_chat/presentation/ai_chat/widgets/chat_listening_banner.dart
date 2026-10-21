import 'package:flutter/material.dart';

// ─── Listening banner ─────────────────────────────────────────────────────────

class ChatListeningBanner extends StatelessWidget {
  final AnimationController controller;
  const ChatListeningBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.red.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_rounded, color: Colors.red.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                'En écoute... Parlez maintenant',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Animated dots
              ...List.generate(3, (i) {
                final t = (controller.value * 3 - i).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600.withValues(alpha: 0.3 + t * 0.7),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
