import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../utils/location_service.dart';
import '../../../features/checkout/data/models/delivery_address.dart';

const _purple = Color(0xFF6C3DE1);

/// Phase 2 of MapAddressPicker: a full-screen map with a pin fixed in the
/// middle. The customer drags the map under the pin; the address under it
/// is looked up when the map stops.
///
/// Stack, bottom to top: GoogleMap, _CenterPin, _MapTopBar (back + address
/// + label), _ConfirmPanel ("Confirmer cet emplacement"). Confirm pops the
/// route with a [DeliveryAddress].
class MapFineTuneScreen extends StatefulWidget {
  final String label;
  final double initialLatitude;
  final double initialLongitude;
  final String initialAddress;
  final VoidCallback onBack;

  /// True while the parent is still waiting on a GPS fix. The map is already
  /// interactive; this only drives a small "locating" hint.
  final bool isLocating;

  const MapFineTuneScreen({
    super.key,
    required this.label,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialAddress,
    required this.onBack,
    this.isLocating = false,
  });

  @override
  State<MapFineTuneScreen> createState() => _MapFineTuneScreenState();
}

class _MapFineTuneScreenState extends State<MapFineTuneScreen>
    with SingleTickerProviderStateMixin {
  gm.GoogleMapController? _map;
  bool _isDragging = false;
  bool _isGeocoding = false;
  bool _hasAddress = false;
  bool _userHasDragged = false;
  bool _isProgrammaticMove = false;
  Timer? _programmaticMoveTimer;
  Timer? _geocodeDebounce;

  late String _addressText;
  late double _currentLat;
  late double _currentLng;

  late final AnimationController _pinController;
  late final Animation<double> _pinAnim;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLatitude;
    _currentLng = widget.initialLongitude;
    _addressText = widget.initialAddress.isNotEmpty
        ? widget.initialAddress
        : 'Glissez la carte vers l\'emplacement souhaité';
    _hasAddress = widget.initialAddress.isNotEmpty;

    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pinAnim = Tween<double>(begin: 0, end: -16).animate(
      CurvedAnimation(parent: _pinController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _programmaticMoveTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _programmaticFlyTo(double lat, double lng) async {
    _programmaticMoveTimer?.cancel();
    _isProgrammaticMove = true;
    await _map?.animateCamera(
      gm.CameraUpdate.newCameraPosition(
        gm.CameraPosition(target: gm.LatLng(lat, lng), zoom: 16),
      ),
    );
    _programmaticMoveTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _isProgrammaticMove = false;
    });
  }

  void _onMapCreated(gm.GoogleMapController map) {
    _map = map;
    // Fly to the pre-chosen location once the map is ready.
    _programmaticFlyTo(widget.initialLatitude, widget.initialLongitude);
  }

  /// Google reports the camera position on every move tick, so the centre is
  /// tracked here instead of being queried from the controller on idle (Mapbox's
  /// getCameraState has no direct Google equivalent).
  void _onCameraMove(gm.CameraPosition position) {
    _currentLat = position.target.latitude;
    _currentLng = position.target.longitude;
    if (!_isProgrammaticMove && !_userHasDragged) {
      setState(() => _userHasDragged = true);
    }
    if (!_isProgrammaticMove && !_isDragging) {
      setState(() => _isDragging = true);
      _pinController.forward();
    }
    _geocodeDebounce?.cancel();
  }

  void _onCameraIdle() {
    if (_isDragging) {
      setState(() => _isDragging = false);
      _pinController.reverse();
    }
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 300), _geocodeCenter);
  }

  Future<void> _geocodeCenter() async {
    if (_map == null) return;
    setState(() => _isGeocoding = true);
    try {
      // _currentLat/_currentLng are kept current by _onCameraMove.
      final lat = _currentLat;
      final lng = _currentLng;
      final address = await LocationService.getAddressFromCoordinates(lat, lng);
      if (mounted) {
        setState(() {
          _addressText = address;
          _isGeocoding = false;
          _hasAddress = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _confirm() {
    final address = DeliveryAddress(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: widget.label,
      fullAddress: _addressText,
      latitude: _currentLat,
      longitude: _currentLng,
    );
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isBusy = _isGeocoding || _isDragging;

    return Scaffold(
      body: Stack(
        children: [
          gm.GoogleMap(
            initialCameraPosition: gm.CameraPosition(
              target: gm.LatLng(_currentLat, _currentLng),
              zoom: 16,
            ),
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
          ),
          Center(
            child: _CenterPin(
              controller: _pinController,
              lift: _pinAnim,
              isDragging: _isDragging,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _MapTopBar(
              label: widget.label,
              addressText: _addressText,
              isBusy: isBusy,
              onBack: widget.onBack,
            ),
          ),
          Positioned(
            bottom: safeBottom + 20,
            left: 16,
            right: 16,
            child: _ConfirmPanel(
              isBusy: isBusy,
              userHasDragged: _userHasDragged,
              hasAddress: _hasAddress,
              addressText: _addressText,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

/// The purple pin in the middle of the map. It lifts up while the map is
/// dragged and its shadow shrinks.
class _CenterPin extends StatelessWidget {
  final AnimationController controller;
  final Animation<double> lift;
  final bool isDragging;

  const _CenterPin({
    required this.controller,
    required this.lift,
    required this.isDragging,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: lift,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -32 + lift.value),
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, 32 - lift.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isDragging ? 8 : 14,
                height: isDragging ? 4 : 6,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _purple,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
          CustomPaint(
            size: const Size(16, 8),
            painter: _PinTipPainter(),
          ),
        ],
      ),
    );
  }
}

/// Top of the map: round back button, white card with the address (or
/// "Localisation…"), and the purple label pill under it.
class _MapTopBar extends StatelessWidget {
  final String label;
  final String addressText;
  final bool isBusy;
  final VoidCallback onBack;

  const _MapTopBar({
    required this.label,
    required this.addressText,
    required this.isBusy,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: _purple, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: isBusy
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _purple,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.mapLocating,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              addressText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom of the map: a white hint ("Glissez pour ajuster la position" /
/// the address) and the purple "Confirmer cet emplacement" button,
/// disabled until an address is known and the map is still.
class _ConfirmPanel extends StatelessWidget {
  final bool isBusy;
  final bool userHasDragged;
  final bool hasAddress;
  final String addressText;
  final VoidCallback onConfirm;

  const _ConfirmPanel({
    required this.isBusy,
    required this.userHasDragged,
    required this.hasAddress,
    required this.addressText,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBusy
                      ? AppLocalizations.of(context)!.mapLocatingInProgress
                      : !userHasDragged
                          ? AppLocalizations.of(context)!.mapDragToAdjust
                          : hasAddress
                              ? addressText
                              : AppLocalizations.of(context)!.mapDragToPlace,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: (isBusy || !hasAddress) ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _purple.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.mapConfirmLocation,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C3DE1)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
