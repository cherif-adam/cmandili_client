import 'dart:ui';

import 'package:flutter/material.dart';

/// The frosted white card of the forgot / reset password screens.
class PasswordGlassCard extends StatelessWidget {
  final Widget child;

  const PasswordGlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(sw * 0.07),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(sw * 0.06),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(sw * 0.07),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: sw * 0.07,
                offset: Offset(0, sh * 0.012),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
