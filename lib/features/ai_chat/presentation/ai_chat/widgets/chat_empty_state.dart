import 'package:flutter/material.dart';

import '../chat_palette.dart';
import 'chat_suggestion_chip.dart';

/// A fresh chat: orange round logo, "Cmandili Assistant", a short intro,
/// and the starter suggestion chips.
class ChatEmptyState extends StatelessWidget {
  final List<(String emoji, String label, String prompt)> suggestions;
  final ValueChanged<String> onSuggestion;

  const ChatEmptyState({
    super.key,
    required this.suggestions,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [kChatOrangeLight, kChatOrange]),
              boxShadow: [
                BoxShadow(color: kChatOrange.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cmandili Assistant',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kChatTextDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre conseiller nutrition et découverte culinaire en Tunisie.\nDites-moi ce que vous cherchez !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: kChatTextMid, height: 1.4),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: suggestions.map((s) {
              final (emoji, label, prompt) = s;
              return ChatSuggestionChip(
                emoji: emoji,
                label: label,
                onTap: () => onSuggestion(prompt),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
