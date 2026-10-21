import 'package:flutter/material.dart';

import '../../../../../models/chat_message.dart';
import '../chat_palette.dart';
import 'chat_product_image.dart';
import 'chat_star_rating.dart';

// ─── Task 2: Food Card (CLICKABLE) ────────────────────────────────────────────

class ChatFoodCard extends StatelessWidget {
  final ProductResult product;
  final VoidCallback onTap; // ← triggers restaurant navigation
  const ChatFoodCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // ── Task 2: onTap navigates to RestaurantDetailScreen ──────────
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 112, width: double.infinity,
                      child: ChatProductImage(
                        imageUrl: product.imageUrl,
                        iconFallback: '🍽️',
                        bgColor: const Color(0xFFFFF3E0),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kChatOrangeLight, kChatOrange]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: kChatOrange.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          product.price == 0.0 ? 'Gratuit' : '${product.price.toStringAsFixed(3)} TND',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kChatTextDark, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.storefront_rounded, size: 11, color: kChatTextMid.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                product.sourceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: kChatTextMid.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                        if (product.rating != null) ...[
                          const SizedBox(height: 4),
                          ChatStarRating(rating: product.rating!),
                        ],
                        // ── Tap hint ───────────────────────────────────────
                        const Spacer(),
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, size: 11, color: kChatOrange),
                            SizedBox(width: 3),
                            Text('Commander', style: TextStyle(fontSize: 10, color: kChatOrange, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
