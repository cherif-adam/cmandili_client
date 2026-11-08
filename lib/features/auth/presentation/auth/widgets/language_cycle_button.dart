import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/localization_provider.dart';
import '../../../../../core/theme/app_colors.dart';

/// The round 🌐 button at the top right of the login screen. Each tap
/// switches language: English → العربية → Français → English.
class LanguageCycleButton extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const LanguageCycleButton({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  static String _next(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'ar';
      case 'ar':
        return 'fr';
      default:
        return 'en';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localizationProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: screenHeight * 0.02,
          right: screenWidth * 0.05,
        ),
        child: IconButton(
          onPressed: () {
            ref
                .read(localizationProvider.notifier)
                .setLocale(Locale(_next(locale.languageCode)));
          },
          icon: Container(
            padding: EdgeInsets.all(screenWidth * 0.025),
            decoration: BoxDecoration(
              // On the light background: white chip, deep-orange icon.
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.splashAmber.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.splashOrange.withValues(alpha: 0.15),
                  blurRadius: screenWidth * 0.02,
                  offset: Offset(0, screenHeight * 0.004),
                ),
              ],
            ),
            child: Icon(
              Icons.language_rounded,
              color: AppColors.brandOrangeDeep,
              size: screenWidth * 0.06,
            ),
          ),
        ),
      ),
    );
  }
}
