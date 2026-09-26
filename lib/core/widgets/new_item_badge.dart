import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../theme/app_colors.dart';

/// Small green "Nouveau" pill shown next to an item's name for the first
/// 24 hours after a shop adds it — the item-level twin of the "Nouveau"
/// badge on shops added in the last 7 days.
class NewItemBadge extends StatelessWidget {
  const NewItemBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        AppLocalizations.of(context)!.newItemBadge,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
