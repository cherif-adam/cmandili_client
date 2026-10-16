import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/widgets/map_address_picker.dart';
import '../data/models/delivery_address.dart';
import '../../profile/providers/address_provider.dart';
import 'widgets/add_address_sheet.dart';
import 'widgets/address_option_card.dart';
import 'widgets/selectable_address_card.dart';

/// "Choisir une adresse" (opened from checkout), top to bottom:
///
///   AddressOptionCard   use my current location
///   AddressOptionCard   choose a point on the map (not saved)
///   "Adresses enregistrées" ........ + Ajouter
///   list of SelectableAddressCard
///
/// Pops with the chosen DeliveryAddress.
class AddressSelectionScreen extends ConsumerStatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  ConsumerState<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends ConsumerState<AddressSelectionScreen> {
  bool _isLoadingCurrentLocation = false;

  /// Opens the map directly and returns whatever point the customer drops,
  /// without saving it to their address book. Used for one-off deliveries.
  Future<void> _pickOnMap() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => MapAddressPicker(
          label: AppLocalizations.of(context)!.chooseOnMap,
          startOnMap: true,
        ),
      ),
    );
    if (address != null && mounted) Navigator.pop(context, address);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingCurrentLocation = true);

    try {
      final position = await LocationService.getCurrentPosition();
      
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.couldNotGetLocation),
            ),
          );
        }
        return;
      }

      final address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        final deliveryAddress = DeliveryAddress(
          id: const Uuid().v4(),
          label: AppLocalizations.of(context)!.currentLocation,
          fullAddress: address,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        Navigator.pop(context, deliveryAddress);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCurrentLocation = false);
      }
    }
  }

  Future<void> _addNewAddress() async {
    // Pick the spot on the map first. Typing a free-text address and geocoding
    // it silently fell back to a hardcoded Tunis point whenever the lookup
    // missed, so addresses could be saved kilometres from where the customer
    // actually lives. The map always yields real coordinates.
    final picked = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => MapAddressPicker(
          label: AppLocalizations.of(context)!.addNewAddress,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddAddressSheet(
        picked: picked,
        onAddressAdded: (address) {
          // Pass through the coordinates _saveAddress() already geocoded —
          // avoids a second geocode call and, more importantly, avoids the
          // notifier's own hardcoded-placeholder fallback for this address.
          ref.read(addressProvider.notifier).addAddress(
                address.label,
                address.fullAddress,
                latitude: address.latitude,
                longitude: address.longitude,
              );
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedAddresses = [
      for (final saved in ref.watch(addressProvider))
        DeliveryAddress(
          id: saved.id,
          label: saved.name,
          fullAddress: saved.fullAddress,
          latitude: saved.latitude,
          longitude: saved.longitude,
          isDefault: saved.isDefault,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectAddress),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AddressOptionCard(
            icon: Icons.my_location,
            color: AppColors.primary,
            iconBackgroundAlpha: 0.1,
            title: AppLocalizations.of(context)!.useCurrentLocation,
            subtitle: _isLoadingCurrentLocation
                ? AppLocalizations.of(context)!.gettingLocation
                : AppLocalizations.of(context)!.enableLocationToDeliver,
            loading: _isLoadingCurrentLocation,
            onTap: _isLoadingCurrentLocation ? null : _useCurrentLocation,
          ),
          const SizedBox(height: 12),

          // A one-off delivery (a friend's place, a café) does not belong in
          // the saved list: this drops the customer straight on the map — no
          // name, no save, just a pin.
          AddressOptionCard(
            icon: Icons.map_rounded,
            color: AppColors.secondary,
            iconBackgroundAlpha: 0.12,
            title: AppLocalizations.of(context)!.chooseOnMap,
            subtitle: AppLocalizations.of(context)!.chooseOnMapSubtitle,
            onTap: _pickOnMap,
          ),
          const SizedBox(height: 24),

          // ── Saved addresses ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.savedAddresses,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _addNewAddress,
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.addNew),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final address in savedAddresses)
            SelectableAddressCard(
              address: address,
              onTap: () => Navigator.pop(context, address),
            ),
        ],
      ),
    );
  }
}
