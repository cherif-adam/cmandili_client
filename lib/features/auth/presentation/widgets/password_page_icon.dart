import 'package:flutter/material.dart';

/// The big white icon in a translucent circle at the top of the forgot /
/// reset password screens (🔒 / 🛡).
class PasswordPageIcon extends StatelessWidget {
  final IconData icon;

  const PasswordPageIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(sw * 0.05),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: sw * 0.14, color: Colors.white),
    );
  }
}
