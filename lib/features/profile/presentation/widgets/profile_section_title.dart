import 'package:flutter/material.dart';

/// A bold section title in the profile tab: "Compte", "Paramètres".
class ProfileSectionTitle extends StatelessWidget {
  final String title;
  final double screenWidth;

  const ProfileSectionTitle({
    super.key,
    required this.title,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: screenWidth * 0.04,
        left: screenWidth * 0.01,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }
}
