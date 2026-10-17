import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// "Supprimer votre compte ?" — says what is deleted and what is kept, with
/// a red "Supprimer" button. Returns true only when the customer confirms.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.delete_forever_rounded,
          color: AppColors.error, size: 36),
      title: Text(l.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Text(l.deleteAccountBody, style: const TextStyle(height: 1.4)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l.deleteAccountConfirm),
        ),
      ],
    ),
  );
  return confirmed == true;
}
