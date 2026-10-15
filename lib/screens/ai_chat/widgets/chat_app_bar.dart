import 'package:flutter/material.dart';

import '../chat_palette.dart';
import 'chat_app_bar_button.dart';
import 'chat_service_pill.dart';

/// The orange gradient header of the AI chat: back button, logo,
/// "Amana Assistant" + online / typing status, the Food and P2P pills, and
/// the clear-conversation button.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _toolbarH = 68;

  /// Height of the phone's status bar, read by the screen.
  final double statusBarHeight;
  final bool isTyping;
  final VoidCallback onClear;

  const ChatAppBar({
    super.key,
    required this.statusBarHeight,
    required this.isTyping,
    required this.onClear,
  });

  @override
  Size get preferredSize => Size.fromHeight(_toolbarH + statusBarHeight);

  @override
  Widget build(BuildContext context) {
    final double statusBarH = statusBarHeight;
    const double toolbarH   = _toolbarH;
    // Usable width inside the 12dp horizontal padding applied below. The two
    // labelled pills and the buttons take a fixed slice of the row; under this
    // threshold what is left for the title column is too narrow for the
    // longest status text ("En train d'écrire..."), so the pills drop their
    // labels and keep the emoji.
    final bool compactPills = MediaQuery.sizeOf(context).width - 24 < 380;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kChatOrangeDark, kChatOrange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33FF9800),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(top: statusBarH, left: 12, right: 12),
        child: SizedBox(
          height: toolbarH,
          child: Row(
            children: [
              ChatAppBarButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amana Assistant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: kChatGreenDot, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            isTyping ? 'En train d\'écrire...' : 'En ligne',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ChatServicePill(emoji: '🍽️', label: 'Food', compact: compactPills),
              const SizedBox(width: 6),
              ChatServicePill(emoji: '📦', label: 'P2P', compact: compactPills),
              const SizedBox(width: 6),
              ChatAppBarButton(
                icon: Icons.delete_outline_rounded,
                onTap: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
