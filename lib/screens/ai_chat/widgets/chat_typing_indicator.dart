import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chat_palette.dart';
import 'chat_ai_avatar.dart';

/// The assistant's "…" bubble: its avatar and three bouncing orange dots.
class ChatTypingIndicator extends StatelessWidget {
  final AnimationController controller;
  const ChatTypingIndicator({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.only(right: 8), child: ChatAiAvatar()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: kChatAiBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [BoxShadow(color: kChatAiBubbleShadow, blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => _BouncingDot(controller: controller, delay: i * 0.22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  const _BouncingDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = (controller.value + delay) % 1.0;
        final offset = -math.sin(t * math.pi) * 6;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          transform: Matrix4.translationValues(0, offset, 0),
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: kChatOrange.withValues(alpha: 0.55 + 0.45 * math.sin(t * math.pi)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
