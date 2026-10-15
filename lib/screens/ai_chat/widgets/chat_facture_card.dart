import 'package:flutter/material.dart';

import '../../../models/chat_message.dart';
import '../chat_palette.dart';
import 'chat_decor_circle.dart';

// ─── Facture Card ──────────────────────────────────────────────────────────────
// Facture answers used to be text-only ("rendez-vous dans la section
// Facture…"), leaving the user to go find it. Same shape as the P2P card so
// the two standalone services read alike; the fee shown comes from the
// service's own kFlatDeliveryFee, never from the model.

class ChatFactureCard extends StatelessWidget {
  final ProductResult product;
  final VoidCallback onTap;
  const ChatFactureCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kChatOrange.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          const Positioned(right: -18, top: -18, child: ChatDecorCircle(size: 110, opacity: 0.05)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: kChatOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('🧾', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  product.description ?? '',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: double.infinity, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kChatOrangeLight, kChatOrangeDark], begin: Alignment.centerLeft, end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: kChatOrange.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Text('Payer une facture  →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
