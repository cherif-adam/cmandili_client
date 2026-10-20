import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// "Se connecter | S'inscrire" — the pill-shaped switch at the top of the
/// login card. The selected side is filled green.
class AuthTabBar extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int> onTap;
  final double screenWidth;
  final double screenHeight;

  const AuthTabBar({
    super.key,
    required this.controller,
    required this.onTap,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: screenHeight * 0.055,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(screenWidth * 0.08),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF0D9488)],
          ),
          borderRadius: BorderRadius.circular(screenWidth * 0.08),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: screenWidth * 0.03,
              offset: Offset(0, screenHeight * 0.005),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.04),
        tabs: [
          Tab(key: const Key('auth_tab_signin'), text: AppLocalizations.of(context)!.signIn),
          Tab(key: const Key('auth_tab_signup'), text: AppLocalizations.of(context)!.signUp),
        ],
        onTap: onTap,
      ),
    );
  }
}
