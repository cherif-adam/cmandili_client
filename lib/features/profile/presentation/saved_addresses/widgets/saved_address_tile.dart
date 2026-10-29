import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../providers/address_provider.dart';

/// One saved address: 🏠 / 📍 name, full address, and either the green
/// "Par défaut" chip or a "Définir par défaut" button. Swipe left (red
/// background) to delete it.
class SavedAddressTile extends StatelessWidget {
  final Address address;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const SavedAddressTile({
    super.key,
    required this.address,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(address.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(
            address.isDefault ? Icons.home_filled : Icons.location_on_outlined,
            color: AppColors.primary,
          ),
          title: Text(
            address.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            address.fullAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Capped: on a 320 px phone "Définir par défaut" took the whole
          // tile and ListTile refused to lay out ("Trailing widget consumes
          // the entire tile width"). It wraps onto two lines instead.
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 104),
            child: address.isDefault
                ? Chip(
                    label: Text(AppLocalizations.of(context)!.defaultLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: AppColors.primary,
                  )
                : TextButton(
                    onPressed: onSetDefault,
                    child: Text(
                      AppLocalizations.of(context)!.setDefault,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
