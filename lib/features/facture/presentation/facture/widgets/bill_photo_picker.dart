import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import 'facture_colors.dart';

/// The optional bill photo: an orange "Ajouter photo…" button, or — once a
/// photo is picked — the photo with a red "Supprimer la photo" under it.
class BillPhotoPicker extends StatelessWidget {
  final File? photo;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const BillPhotoPicker({
    super.key,
    required this.photo,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text(AppLocalizations.of(context)!.factureAddBillPhoto),
        style: OutlinedButton.styleFrom(
          foregroundColor: kFactureOrange,
          side: const BorderSide(color: kFactureOrange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            photo!,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: Text(AppLocalizations.of(context)!.factureRemovePhoto),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
        ),
      ],
    );
  }
}
