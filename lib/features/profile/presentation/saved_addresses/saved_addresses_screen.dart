import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../providers/address_provider.dart';
import '../../../../core/widgets/map_address_picker.dart';
import '../../../checkout/data/models/delivery_address.dart';
import 'widgets/add_address_dialog.dart';
import 'widgets/saved_address_tile.dart';

/// The customer's saved delivery addresses: one SavedAddressTile each
/// (swipe left to delete, "Par défaut" chip or a button to make it the
/// default). The + in the app bar adds one, picked on the map.
///
/// UI only: the address book lives in [addressProvider] (AddressNotifier,
/// AddressRepository behind it).
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
          : _AddressesList(
              addresses: addresses,
              onDelete: (address) =>
                  ref.read(addressProvider.notifier).deleteAddress(address.id),
              onSetDefault: (address) =>
                  ref.read(addressProvider.notifier).setDefault(address.id),
            ),
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AddAddressDialog(
        picked: picked,
        onSave: (name) => ref.read(addressProvider.notifier).addAddress(
              name,
              picked.fullAddress,
              latitude: picked.latitude,
              longitude: picked.longitude,
            ),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// One SavedAddressTile per address. Deleting shows "Adresse supprimée".
class _AddressesList extends StatelessWidget {
  const _AddressesList({
    required this.addresses,
    required this.onDelete,
    required this.onSetDefault,
  });

  final List<Address> addresses;
  final ValueChanged<Address> onDelete;
  final ValueChanged<Address> onSetDefault;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        return SavedAddressTile(
          address: address,
          onDelete: () {
            onDelete(address);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.addressRemovedSuccess)),
            );
          },
          onSetDefault: () => onSetDefault(address),
        );
      },
    );
  }
}
