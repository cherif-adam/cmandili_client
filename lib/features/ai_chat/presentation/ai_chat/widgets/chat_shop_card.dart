import 'package:flutter/material.dart';

import '../../../../../models/chat_message.dart';
import '../chat_palette.dart';
import 'chat_product_image.dart';
import 'chat_star_rating.dart';

// ─── Shop Card ─────────────────────────────────────────────────────────────────

class ChatShopCard extends StatelessWidget {
  final ProductResult product;
  /// Opens the shop in VendorDetailScreen so the item can actually be ordered.
  /// The card used to be inert — results were visible but not buyable.
  final VoidCallback onTap;
  const ChatShopCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 162,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 112, width: double.infinity,
                  child: ChatProductImage(imageUrl: product.imageUrl, iconFallback: '🛍️', bgColor: const Color(0xFFE8F5E9)),
                ),
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      product.sourceName.isEmpty ? 'Magasin' : product.sourceName,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
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
                    Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kChatTextDark)),
                    const SizedBox(height: 4),
                    if (product.price > 0)
                      Text('${product.price.toStringAsFixed(3)} TND',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                    if (product.rating != null) ...[
                      const SizedBox(height: 4),
                      ChatStarRating(rating: product.rating!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
