import 'package:flutter/material.dart';

import '../utils/location_service.dart';
import 'map_address_picker/address_choice_screen.dart';
import 'map_address_picker/map_fine_tune_screen.dart';

/// Two-phase address picker modelled on Glovo/Yassir:
///
/// Phase 1 — Choice screen (map_address_picker/address_choice_screen.dart)
///   • "Utiliser ma position actuelle" button (GPS)
///   • Search field with Google Places autocomplete
///
/// Phase 2 — Map fine-tune (map_address_picker/map_fine_tune_screen.dart)
///   • Map pre-centred on the chosen location
///   • User drags to fine-adjust; confirm button returns [DeliveryAddress]
///
/// Usage:
/// ```dart
/// final address = await Navigator.push<DeliveryAddress>(
///   context,
///   MaterialPageRoute(builder: (_) => MapAddressPicker(label: 'Ramassage')),
/// );
/// ```
class MapAddressPicker extends StatefulWidget {
  final String label;

  /// Skip the search/choice screen and open the map straight away, centred on
  /// the device's current position.
  ///
  /// For a one-off delivery the customer already knows where they are — the
  /// point is simply not the address they saved as "maison". Making them pass
  /// through a search box first, then the map, is two screens of friction for
  /// something they can express with one drag of a pin.
  final bool startOnMap;

  const MapAddressPicker({
    super.key,
    required this.label,
    this.startOnMap = false,
  });

  @override
  State<MapAddressPicker> createState() => _MapAddressPickerState();
}

class _MapAddressPickerState extends State<MapAddressPicker> {
  // ── Phase control ───────────────────────────────────────────────────────────
  bool _showMap = false;
  double _startLat = 35.6835;
  double _startLng = 10.0966;
  String _startAddress = '';
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.startOnMap) _jumpToCurrentPosition();
  }

  /// Opens the map immediately, centred on the GPS fix when one arrives.
  ///
  /// The map is shown right away rather than after the fix: waiting would
  /// leave the customer on a blank screen for the seconds a cold GPS lock
  /// takes, and the pin can be dragged regardless. If the fix fails we simply
  /// stay on the default centre instead of blocking.
  Future<void> _jumpToCurrentPosition() async {
    setState(() {
      _showMap = true;
      _locating = true;
    });
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted || position == null) return;
      final address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _startLat = position.latitude;
        _startLng = position.longitude;
        _startAddress = address;
      });
    } catch (_) {
      // Keep the default centre; the pin is still draggable.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _openMapAt(double lat, double lng, String address) {
    setState(() {
      _startLat = lat;
      _startLng = lng;
      _startAddress = address;
      _showMap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showMap) {
      return MapFineTuneScreen(
        // Keying on the coordinates rebuilds the map once the GPS fix
        // arrives, so it re-centres on the customer instead of sitting on
        // the default city centre.
        key: ValueKey('$_startLat,$_startLng'),
        label: widget.label,
        initialLatitude: _startLat,
        initialLongitude: _startLng,
        initialAddress: _startAddress,
        isLocating: _locating,
        // Opened straight on the map: there is no choice screen to go back
        // to, so back leaves the picker entirely.
        onBack: widget.startOnMap
            ? () => Navigator.of(context).pop()
            : () => setState(() => _showMap = false),
      );
    }
    return AddressChoiceScreen(
      label: widget.label,
      onLocationChosen: _openMapAt,
    );
  }
}
