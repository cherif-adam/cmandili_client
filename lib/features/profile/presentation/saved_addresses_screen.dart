import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/address_provider.dart';
import '../../../core/widgets/map_address_picker.dart';
import '../../checkout/data/models/delivery_address.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.savedAddresses, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _showAddAddressDialog(context, ref),
          ),
        ],
      ),
      body: addresses.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noAddressesSaved))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Dismissible(
                  key: Key(address.id),
                  direction: DismissDirection.endToStart,
                  background: _buildDeleteBackground(),
                  onDismissed: (direction) {
                    ref.read(addressProvider.notifier).deleteAddress(address.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.addressRemovedSuccess)),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(
                        address.isDefault ? Icons.home_filled : Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(address.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(address.fullAddress),
                      trailing: address.isDefault
                          ? Chip(
                              label: Text(AppLocalizations.of(context)!.defaultLabel, style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: AppColors.primary,
                            )
                          : TextButton(
                              onPressed: () {
                                ref.read(addressProvider.notifier).setDefault(address.id);
                              },
                              child: Text(AppLocalizations.of(context)!.setDefault),
                            ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  /// Pick the location on the map, then ask only for a label. The old flow was
  /// two free-text fields with no coordinates at all, so addAddress() fell back
  /// to 0,0 whenever geocoding the typed string failed -- a pin in the Gulf of
  /// Guinea that no driver could ever deliver to.
  Future<void> _showAddAddressDialog(BuildContext context, WidgetRef ref) async {
    final picked = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => MapAddressPicker(
          label: AppLocalizations.of(context)!.addNewAddress,
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    final nameController = TextEditingController(text: picked.label);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext)!.addNewAddress),
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
                    picked.fullAddress,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(dialogContext)!.labelHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(dialogContext)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              ref.read(addressProvider.notifier).addAddress(
                    nameController.text,
                    picked.fullAddress,
                    latitude: picked.latitude,
                    longitude: picked.longitude,
                  );
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(dialogContext)!.save),
          ),
        ],
      ),
    );
  }
}
