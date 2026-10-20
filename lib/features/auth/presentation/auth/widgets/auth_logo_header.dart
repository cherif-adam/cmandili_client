import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// The top of the login screen: the logo in a white circle, "Amana" and
/// "Bienvenue".
class AuthLogoHeader extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const AuthLogoHeader({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: screenWidth * 0.05,
                offset: Offset(0, screenHeight * 0.01),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: screenWidth * 0.15,
            height: screenWidth * 0.15,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          AppLocalizations.of(context)!.appTitle,
          style: TextStyle(
            fontSize: screenWidth * 0.09,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: screenHeight * 0.005),
        Text(
          AppLocalizations.of(context)!.welcome,
          style: TextStyle(
            fontSize: screenWidth * 0.038,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
