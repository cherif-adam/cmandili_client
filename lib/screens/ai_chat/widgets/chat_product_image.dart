import 'package:flutter/material.dart';

import '../chat_palette.dart';

// ─── Product image with fallback ───────────────────────────────────────────────

class ChatProductImage extends StatelessWidget {
  final String? imageUrl;
  final String iconFallback;
  final Color? bgColor;

  const ChatProductImage({super.key, required this.imageUrl, required this.iconFallback, this.bgColor});

  @override
  Widget build(BuildContext context) {
    final isValid = imageUrl != null &&
        imageUrl!.isNotEmpty &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    if (!isValid) return _placeholder();

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return _placeholder(loading: true);
      },
      errorBuilder: (ctx, err, st) => _placeholder(),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: bgColor ?? const Color(0xFFFFF3E0),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(kChatOrange)),
              )
            : Text(iconFallback, style: const TextStyle(fontSize: 36)),
      ),
    );
  }
}
