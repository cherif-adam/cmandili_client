import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../checkout/data/models/delivery_address.dart';
import '../../../providers/address_provider.dart';

/// The address picked on the map, then its name, typed by the customer.
/// "Enregistrer" needs a name ([AddressNotifier.canSaveAddress]); without
/// one it says so.
///
/// The name starts EMPTY. It used to be pre-filled with the picked address's
/// label, which is the map screen's title: saving without typing a name
/// stored "Ajouter une nouvelle adresse" as the address name.
class AddAddressDialog extends StatefulWidget {
  const AddAddressDialog({super.key, required this.picked, required this.onSave});

  final DeliveryAddress picked;
  final ValueChanged<String> onSave;

  @override
  State<AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<AddAddressDialog> {
  final nameController = TextEditingController();
  bool _nameMissing = false;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    if (!AddressNotifier.canSaveAddress(name)) {
      setState(() => _nameMissing = true);
      return;
    }
    widget.onSave(name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.addNewAddress),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.picked.fullAddress,
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            autofocus: true,
            onChanged: (_) {
              if (_nameMissing) setState(() => _nameMissing = false);
            },
            decoration: InputDecoration(
              labelText: l.labelHint,
              errorText: _nameMissing ? l.addressLabelRequired : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
