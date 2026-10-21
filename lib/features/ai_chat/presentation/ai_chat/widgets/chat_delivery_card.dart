import 'package:flutter/material.dart';

import '../../../../../models/chat_message.dart';
import '../chat_palette.dart';
import 'chat_decor_circle.dart';

// ─── Delivery P2P Card ─────────────────────────────────────────────────────────

class ChatDeliveryCard extends StatelessWidget {
  final ProductResult product;
  /// Opens CourierScreen. The button used to pop a "bientôt disponible"
  /// snackbar even though the courier flow has shipped.
  final VoidCallback onTap;
  const ChatDeliveryCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kChatOrange.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          const Positioned(right: -18, top: -18, child: ChatDecorCircle(size: 110, opacity: 0.05)),
          const Positioned(right: 20, bottom: -28, child: ChatDecorCircle(size: 85, opacity: 0.05)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: kChatOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('📦', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Livraison P2P', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [kChatOrangeLight, kChatOrange]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Nouveau 🔥', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Envoyez vos colis à vos proches\nvia nos livreurs. Suivi live ! 🏍️',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                ),
                const Spacer(),
                const Row(
                  children: [
                    _Feature(icon: '📍', label: 'Suivi live'),
                    SizedBox(width: 12),
                    _Feature(icon: '⚡', label: 'Express'),
                    SizedBox(width: 12),
                    _Feature(icon: '🔒', label: 'Sécurisé'),
                  ],
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
                      child: Text('Créer une livraison  →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
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

class _Feature extends StatelessWidget {
  final String icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
