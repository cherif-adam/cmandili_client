import 'package:flutter/material.dart';

import '../../../models/chat_message.dart';
import '../chat_palette.dart';
import 'chat_product_image.dart';
import 'chat_star_rating.dart';

// ─── Restaurant Card (CLICKABLE → RestaurantDetailScreen) ─────────────────────
// A VENUE card, not a dish card: no price, no "Commander" — shows the place,
// its rating (when it has one), delivery info, and opens its full menu on tap.

class ChatRestaurantCard extends StatelessWidget {
  final ProductResult product;
  final VoidCallback onTap;
  const ChatRestaurantCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasRating = product.rating != null && product.rating! > 0;
    final dt = product.deliveryTime;
    final fee = product.deliveryFee;

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
                        iconFallback: '🍴',
                        bgColor: const Color(0xFFFFF3E0),
                      ),
                    ),
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Ouvert',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
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
                        if (hasRating) ...[
                          const SizedBox(height: 4),
                          ChatStarRating(rating: product.rating!),
                        ],
                        if (dt != null || fee != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 11, color: kChatTextMid.withValues(alpha: 0.7)),
                              const SizedBox(width: 3),
                              Text(
                                [
                                  if (dt != null) '~$dt min',
                                  if (fee != null) '${fee.toStringAsFixed(3)} TND',
                                ].join(' · '),
                                style: TextStyle(fontSize: 10, color: kChatTextMid.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        const Row(
                          children: [
                            Icon(Icons.restaurant_menu_rounded, size: 11, color: kChatOrange),
                            SizedBox(width: 3),
                            Text('Voir le menu', style: TextStyle(fontSize: 10, color: kChatOrange, fontWeight: FontWeight.w600)),
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
