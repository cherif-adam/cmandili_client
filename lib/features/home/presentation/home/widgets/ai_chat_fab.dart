import 'package:flutter/material.dart';

import '../../../../../screens/ai_chat_screen.dart';

/// The purple round button that opens the AI assistant (home tab only).
class AiChatFab extends StatelessWidget {
  const AiChatFab({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.1),
      child: FloatingActionButton(
        heroTag: 'ai_chat_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        ),
        backgroundColor: const Color(0xFF6C3DE1),
        tooltip: 'AI Chat',
        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
      ),
    );
  }
}
