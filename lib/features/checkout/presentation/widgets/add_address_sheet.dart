import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../data/models/delivery_address.dart';

/// Bottom sheet after the customer dropped a pin for a new saved address:
/// label, full address (pre-filled), apartment, floor, "Enregistrer".
/// The coordinates come straight from the pin.
class AddAddressSheet extends StatefulWidget {
  final Function(DeliveryAddress) onAddressAdded;

  /// The point the customer dropped on the map. Its coordinates are used
  /// verbatim; only the label and apartment/floor details are typed here.
  final DeliveryAddress picked;

  const AddAddressSheet({super.key, required this.onAddressAdded, required this.picked});

  @override
  State<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<AddAddressSheet> {
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
