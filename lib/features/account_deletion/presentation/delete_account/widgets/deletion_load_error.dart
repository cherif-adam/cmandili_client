import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// La vérification des blocages n'a pas abouti (réseau). Sans elle, on ne
/// propose pas de supprimer : on propose de réessayer.
class DeletionLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const DeletionLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    return Column(
      children: [
        Text(
          l.deleteAccountLoadError,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: width * 0.037),
        ),
        SizedBox(height: width * 0.03),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l.deleteAccountRetry),
          onPressed: onRetry,
        ),
      ],
    );
  }
}
