import 'package:flutter/material.dart';

// ─── AppBar back button ────────────────────────────────────────────────────────

class ChatAppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const ChatAppBarButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
