import 'package:flutter/material.dart';

// ─── Mic button with pulse animation ──────────────────────────────────────────

class ChatMicButton extends StatelessWidget {
  final bool isListening;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const ChatMicButton({super.key, 
    required this.isListening,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isListening) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3), width: 1.5),
          ),
          child: const Icon(Icons.mic_rounded, color: Color(0xFFFF9800), size: 20),
        ),
      );
    }

    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) {
        final scale = 1.0 + pulseController.value * 0.15;
        return GestureDetector(
          onTap: onTap,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4 + pulseController.value * 0.2),
                    blurRadius: 12 + pulseController.value * 6,
                    spreadRadius: pulseController.value * 3,
                  ),
                ],
              ),
              child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 20),
            ),
          ),
        );
      },
    );
  }
}
