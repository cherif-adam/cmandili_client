import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/widgets/map_address_picker.dart';
import '../data/models/delivery_address.dart';
import '../../profile/providers/address_provider.dart';

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
          SnackBar(content: Text('Error: ${e.toString()}')),
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
      builder: (context) => _AddAddressSheet(
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectAddress),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Use Current Location
          Card(
            child: InkWell(
              onTap: _isLoadingCurrentLocation ? null : _useCurrentLocation,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.useCurrentLocation,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isLoadingCurrentLocation
                                ? AppLocalizations.of(context)!.gettingLocation
                                : AppLocalizations.of(context)!.enableLocationToDeliver,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoadingCurrentLocation)
                      const CircularProgressIndicator()
                    else
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                  ],
                ),
              ),
            ),
          ),
          

          const SizedBox(height: 12),

          // ── Choose a point on the map ──────────────────────────────────
          // A one-off delivery does not belong in the saved list: the
          // customer is at a friend's place, a café, a building site. Making
          // them name and save it clutters the list with entries they will
          // never reuse. This drops them straight on the map — no name, no
          // save, just a pin.
          Card(
            child: InkWell(
              onTap: _pickOnMap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.map_rounded,
                          color: AppColors.secondary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.chooseOnMap,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.chooseOnMapSubtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppColors.textLight),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Saved Addresses
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
          
          ...ref.watch(addressProvider).map((saved) {
            final address = DeliveryAddress(
              id: saved.id,
              label: saved.name,
              fullAddress: saved.fullAddress,
              latitude: saved.latitude,
              longitude: saved.longitude,
              isDefault: saved.isDefault,
            );
            return _AddressCard(
              address: address,
              onTap: () => Navigator.pop(context, address),
            );
          }),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final DeliveryAddress address;
  final VoidCallback onTap;

  const _AddressCard({
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  address.label == 'Home'
                      ? Icons.home
                      : address.label == 'Work'
                          ? Icons.work
                          : Icons.location_on,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.defaultLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.fullAddress,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (address.apartmentNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Apt: ${address.apartmentNumber}, Floor: ${address.floor}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  final Function(DeliveryAddress) onAddressAdded;

  /// The point the customer dropped on the map. Its coordinates are used
  /// verbatim; only the label and apartment/floor details are typed here.
  final DeliveryAddress picked;

  const _AddAddressSheet({required this.onAddressAdded, required this.picked});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _aptController = TextEditingController();
  final _floorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.picked.fullAddress;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _aptController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final address = DeliveryAddress(
        id: const Uuid().v4(),
        label: _labelController.text,
        fullAddress: _addressController.text,
        // Straight from the map pin — never geocoded, never a fallback.
        latitude: widget.picked.latitude,
        longitude: widget.picked.longitude,
        apartmentNumber: _aptController.text.isNotEmpty ? _aptController.text : null,
        floor: _floorController.text.isNotEmpty ? _floorController.text : null,
      );
      widget.onAddressAdded(address);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotGeocode)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.addNewAddress,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.labelHint,
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a label' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.fullAddressLabel,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter an address' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _aptController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.apartment,
                        prefixIcon: const Icon(Icons.apartment),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _floorController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.floor,
                        prefixIcon: const Icon(Icons.stairs),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAddress,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppLocalizations.of(context)!.saveAddress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
