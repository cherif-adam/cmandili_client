import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/map_address_picker.dart';
import '../../data/models/delivery_address.dart';
import 'address_selection_controller.dart';
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
/// Pops with the chosen DeliveryAddress. UI only: the GPS lookup, the
/// address book and saving a new address live in
/// [AddressSelectionController].
class AddressSelectionScreen extends ConsumerStatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  ConsumerState<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends ConsumerState<AddressSelectionScreen> {
  /// This screen's own controller (see [addressSelectionControllerProvider]).
  late final _provider = addressSelectionControllerProvider(Object());

  @override
  Widget build(BuildContext context) {
    final isLoadingCurrentLocation = ref.watch(_provider);
    final savedAddresses = ref.watch(savedDeliveryAddressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectAddress),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LocationOptions(
            isLoadingCurrentLocation: isLoadingCurrentLocation,
            onUseCurrentLocation: _useCurrentLocation,
            onPickOnMap: _pickOnMap,
          ),
          const SizedBox(height: 24),
          _SavedAddresses(
            addresses: savedAddresses,
            onAdd: _addNewAddress,
            onSelect: (address) => Navigator.pop(context, address),
          ),
        ],
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

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
    if (address == null || !mounted) return;
    // The picker names its result after its own title ("Choisir sur la
    // carte"), which then travelled into the order as the address name.
    Navigator.pop(
      context,
      address.copyWith(label: AppLocalizations.of(context)!.deliveryLocation),
    );
  }

  /// Makes sure GPS is on and the app may use it. Asks for the permission
  /// (system prompt) when it can, otherwise shows a dialog that sends the
  /// customer to the right settings page. Returns true when ready to locate.
  Future<bool> _ensureLocationReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await _showLocationDialog(openLocationSettings: true);
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await _showLocationDialog(openLocationSettings: false);
      return false;
    }
    return true;
  }

  Future<void> _showLocationDialog({required bool openLocationSettings}) async {
    if (!mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    String t(String en, String fr, String ar) =>
        lang == 'fr' ? fr : (lang == 'ar' ? ar : en);
    final goToSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Location needed', 'Localisation requise', 'الموقع مطلوب')),
        content: Text(openLocationSettings
            ? t(
                'Turn on location services to deliver to where you are.',
                'Activez la localisation pour livrer à votre position.',
                'فعّل خدمة الموقع للتوصيل إلى مكانك.')
            : t(
                'Allow Cmandili to access your location in the app settings.',
                'Autorisez Cmandili à accéder à votre position dans les paramètres.',
                'اسمح لـ Cmandili بالوصول إلى موقعك من الإعدادات.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Open settings', 'Ouvrir les paramètres', 'فتح الإعدادات')),
          ),
        ],
      ),
    );
    if (goToSettings != true) return;
    if (openLocationSettings) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _useCurrentLocation() async {
    if (!await _ensureLocationReady()) return;
    if (!mounted) return;
    final controller = ref.read(_provider.notifier);
    final label = AppLocalizations.of(context)!.currentLocation;
    try {
      final deliveryAddress = await controller.locate(label: label);
      if (!mounted) return;
      if (deliveryAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couldNotGetLocation),
          ),
        );
        return;
      }
      Navigator.pop(context, deliveryAddress);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.somethingWentWrong)),
        );
      }
    }
  }

  Future<void> _addNewAddress() async {
    // Pick the spot on the map first. Typing a free-text address and geocoding
    // it silently fell back to a hardcoded Tunis point whenever the lookup
    // missed, so addresses could be saved kilometres from where the customer
    // actually lives. The map always yields real coordinates.
    final controller = ref.read(_provider.notifier);
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
          controller.save(address);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// "Use my current location", then "choose a point on the map".
class _LocationOptions extends StatelessWidget {
  const _LocationOptions({
    required this.isLoadingCurrentLocation,
    required this.onUseCurrentLocation,
    required this.onPickOnMap,
  });

  final bool isLoadingCurrentLocation;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddressOptionCard(
          icon: Icons.my_location,
          color: AppColors.primary,
          iconBackgroundAlpha: 0.1,
          title: AppLocalizations.of(context)!.useCurrentLocation,
          subtitle: isLoadingCurrentLocation
              ? AppLocalizations.of(context)!.gettingLocation
              : AppLocalizations.of(context)!.enableLocationToDeliver,
          loading: isLoadingCurrentLocation,
          onTap: isLoadingCurrentLocation ? null : onUseCurrentLocation,
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
          onTap: onPickOnMap,
        ),
      ],
    );
  }
}

/// "Adresses enregistrées" ........ + Ajouter, then one card per address.
class _SavedAddresses extends StatelessWidget {
  const _SavedAddresses({
    required this.addresses,
    required this.onAdd,
    required this.onSelect,
  });

  final List<DeliveryAddress> addresses;
  final VoidCallback onAdd;
  final ValueChanged<DeliveryAddress> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.addNew),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final address in addresses)
          SelectableAddressCard(
            address: address,
            onTap: () => onSelect(address),
          ),
      ],
    );
  }
}
