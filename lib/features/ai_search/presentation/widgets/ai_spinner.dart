import 'package:flutter/material.dart';

/// A purple spinning ring with the ✦ icon in the middle.
class AiSpinner extends StatelessWidget {
  const AiSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(Color(0xFF6C3DE1)),
          ),
          Icon(Icons.auto_awesome_rounded,
              color: Color(0xFF6C3DE1), size: 20),
        ],
      ),
    );
  }
}
