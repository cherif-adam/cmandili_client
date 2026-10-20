import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/providers/localization_provider.dart';
import '../../../../../core/theme/app_colors.dart';

/// Opens the [LanguagePickerSheet] from the bottom of the screen.
void showLanguagePickerSheet(
    BuildContext context, double screenWidth, double screenHeight) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => LanguagePickerSheet(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    ),
  );
}

/// "Langue" — English / العربية / Français, the current one ticked.
/// Picking one switches the app's language and closes the sheet.
class LanguagePickerSheet extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const LanguagePickerSheet({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localizationProvider).languageCode;

    Widget option(String name, String code) => ListTile(
          title: Text(name, style: TextStyle(fontSize: screenWidth * 0.04)),
          trailing: current == code
              ? Icon(Icons.check, color: AppColors.primary, size: screenWidth * 0.06)
              : null,
          onTap: () {
            ref.read(localizationProvider.notifier).setLocale(Locale(code));
            Navigator.pop(context);
          },
        );

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(screenWidth * 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.language,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.055,
                ),
          ),
          SizedBox(height: screenHeight * 0.03),
          option('English', 'en'),
          option('العربية', 'ar'),
          option('Français', 'fr'),
          SizedBox(height: screenHeight * 0.03),
        ],
      ),
    );
  }
}
