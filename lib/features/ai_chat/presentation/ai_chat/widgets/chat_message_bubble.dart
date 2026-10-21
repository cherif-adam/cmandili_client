import 'package:flutter/material.dart';

import '../../../../../models/chat_message.dart';
import '../chat_palette.dart';
import 'chat_ai_avatar.dart';

/// One message of the conversation: the user's orange bubble on the right
/// (with the photo they sent, if any) or the assistant's white bubble on
/// the left with its avatar — then, under it, a horizontal row of product
/// cards when the answer has some.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Builds the card for one product (food, restaurant, shop, P2P, facture).
  final Widget Function(ProductResult product) cardBuilder;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                const Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 4),
                  child: ChatAiAvatar(),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // ── Image preview (if user sent image) ────────────────
                    if (isUser && message.imageFile != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        width: 180,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: kChatOrange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(message.imageFile!, fit: BoxFit.cover),
                        ),
                      ),

                    // ── Text bubble ───────────────────────────────────────
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.74,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                colors: [kChatUserBubbleTop, kChatUserBubbleBot],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUser ? null : kChatAiBubble,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isUser ? 20 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser ? kChatOrange.withValues(alpha: 0.28) : kChatAiBubbleShadow,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : kChatTextDark,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Product cards ─────────────────────────────────────────────────
          if (message.products != null && message.products!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 10, left: !isUser ? 46 : 0),
              child: SizedBox(
                height: message.intent == 'delivery_request' ? 210 : 230,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.products!.length,
                  itemBuilder: (ctx, i) => cardBuilder(message.products![i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
