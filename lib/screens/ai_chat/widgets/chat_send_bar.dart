import 'package:flutter/material.dart';

import '../chat_palette.dart';
import 'chat_input_action_button.dart';
import 'chat_mic_button.dart';

/// The white bar at the bottom of the chat: photo button, the rounded
/// text field (red while listening), mic button and the orange send button.
class ChatSendBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final AnimationController micPulseController;

  /// The phone's bottom system inset, read by the screen.
  final double bottomViewPadding;
  final VoidCallback onImageTap;
  final VoidCallback onMicTap;
  final ValueChanged<String> onSubmitted;

  const ChatSendBar({
    super.key,
    required this.controller,
    required this.isListening,
    required this.micPulseController,
    required this.bottomViewPadding,
    required this.onImageTap,
    required this.onMicTap,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + bottomViewPadding * 0.5,
      ),
      child: Row(
        children: [
          // ── Task 4: Image button ─────────────────────────────────────────
          ChatInputActionButton(
            icon: Icons.add_photo_alternate_rounded,
            color: kChatOrange,
            onTap: onImageTap,
          ),
          const SizedBox(width: 8),

          // ── TextField ────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isListening
                      ? Colors.red.shade300
                      : kChatOrange.withValues(alpha: 0.5),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isListening ? Colors.red : kChatOrange).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                onSubmitted: onSubmitted,
                style: const TextStyle(fontSize: 15, color: kChatTextDark),
                decoration: InputDecoration(
                  hintText: isListening
                      ? 'J\'écoute... parlez maintenant 🎙️'
                      : 'Food, livraison, magasin...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: kChatOrange.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  border: InputBorder.none,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Task 3: Mic button ───────────────────────────────────────────
          ChatMicButton(
            isListening: isListening,
            pulseController: micPulseController,
            onTap: onMicTap,
          ),
          const SizedBox(width: 8),

          // ── Send button ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => onSubmitted(controller.text),
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kChatOrangeLight, kChatOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kChatOrange.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
