import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// The top of the login screen: the client logo (it already spells "AMANA")
/// on the light background, then the welcome line.
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
        Image.asset(
          'assets/branding/logo_client.png',
          width: screenWidth * 0.42,
          height: screenWidth * 0.42,
          fit: BoxFit.contain,
        ),
        SizedBox(height: screenHeight * 0.005),
        Text(
          AppLocalizations.of(context)!.welcome,
          style: TextStyle(
            fontSize: screenWidth * 0.042,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
