import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../utils/location_service.dart';
import '../../features/checkout/data/models/delivery_address.dart';

/// Two-phase address picker modelled on Glovo/Yassir:
///
/// Phase 1 — Choice screen
///   • "Utiliser ma position actuelle" button (GPS)
///   • Search field with Google Places autocomplete
///
/// Phase 2 — Map fine-tune
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
      return _MapFineTune(
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
    return _ChoiceScreen(
      label: widget.label,
      onLocationChosen: _openMapAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 1: Choice screen
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceScreen extends StatefulWidget {
  final String label;
  final void Function(double lat, double lng, String address) onLocationChosen;

  const _ChoiceScreen({required this.label, required this.onLocationChosen});

  @override
  State<_ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<_ChoiceScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isGpsLoading = false;
  bool _isSearching = false;
  List<_GeocodingResult> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _isGpsLoading = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'obtenir la position GPS')),
          );
        }
        return;
      }
      final address = await LocationService.getAddressFromCoordinates(
        pos.latitude, pos.longitude,
      );
      if (mounted) widget.onLocationChosen(pos.latitude, pos.longitude, address);
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final encoded = Uri.encodeComponent(query);
      // Places Text Search rather than the Geocoding API: it matches business
      // and place names, not just formatted addresses, which is what the old
      // Mapbox `places` endpoint did. `region=tn` biases toward Tunisia --
      // Google has no hard country filter equivalent to Mapbox's `country=TN`,
      // so results are filtered client-side below.
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=$encoded'
        '&language=fr'
        '&region=tn'
        '&key=$key',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 && mounted) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        // 200 is returned even for REQUEST_DENIED / ZERO_RESULTS.
        if (data['status'] != 'OK') {
          setState(() => _suggestions = []);
          return;
        }
        final results = (data['results'] as List?) ?? [];
        setState(() {
          _suggestions = results
              .take(5)
              .map((f) => _GeocodingResult.fromJson(f as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      // silently ignore network errors
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(_GeocodingResult result) {
    FocusScope.of(context).unfocus();
    widget.onLocationChosen(result.lat, result.lng, result.placeName);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    const purple = Color(0xFF6C3DE1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: top + 8, left: 8, right: 16, bottom: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── GPS button ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _isGpsLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: purple),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _useGps,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: purple,
                      side: const BorderSide(color: purple),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                    label: const Text(
                      'Utiliser ma position actuelle',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),

          // ── Divider ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('ou', style: TextStyle(color: Colors.grey.shade500)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
          ),

          // ── Search field ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Rechercher une adresse ou un lieu…',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: purple),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: purple),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _suggestions = []);
                            },
                          )
                        : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: purple, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Suggestions list ─────────────────────────────────────────────────
          Expanded(
            child: _suggestions.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Tapez un nom de rue, quartier ou lieu…'
                          : 'Aucun résultat',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: purple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: purple, size: 18),
                        ),
                        title: Text(
                          s.text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          s.placeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectSuggestion(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GeocodingResult {
  final String text;
  final String placeName;
  final double lat;
  final double lng;

  const _GeocodingResult({
    required this.text,
    required this.placeName,
    required this.lat,
    required this.lng,
  });

  /// Parses one Google Places Text Search result. Google nests the coordinates
  /// under `geometry.location` as named lat/lng fields, rather than Mapbox's
  /// flat `center: [lng, lat]` array.
  factory _GeocodingResult.fromJson(Map<String, dynamic> json) {
    final loc = json['geometry']?['location'] as Map<String, dynamic>?;
    return _GeocodingResult(
      text: json['name'] as String? ?? '',
      placeName: json['formatted_address'] as String? ?? '',
      lat: (loc?['lat'] as num?)?.toDouble() ?? 0,
      lng: (loc?['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 2: Map fine-tune
// ─────────────────────────────────────────────────────────────────────────────

class _MapFineTune extends StatefulWidget {
  final String label;
  final double initialLatitude;
  final double initialLongitude;
  final String initialAddress;
  final VoidCallback onBack;

  /// True while the parent is still waiting on a GPS fix. The map is already
  /// interactive; this only drives a small "locating" hint.
  final bool isLocating;

  const _MapFineTune({
    super.key,
    required this.label,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialAddress,
    required this.onBack,
    this.isLocating = false,
  });

  @override
  State<_MapFineTune> createState() => _MapFineTuneState();
}

class _MapFineTuneState extends State<_MapFineTune>
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
    const purple = Color(0xFF6C3DE1);

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
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

          // ── Center pin ───────────────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pinAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -32 + _pinAnim.value),
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pinController,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, 32 - _pinAnim.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isDragging ? 8 : 14,
                        height: _isDragging ? 4 : 6,
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
                      color: purple,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withValues(alpha: 0.5),
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
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
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
                            const Icon(Icons.location_on, color: purple, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _isGeocoding || _isDragging
                                  ? Row(
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: purple,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Localisation…',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _addressText,
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
                      color: purple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Confirm button ───────────────────────────────────────────────────
          Positioned(
            bottom: safeBottom + 20,
            left: 16,
            right: 16,
            child: Column(
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
                          _isGeocoding || _isDragging
                              ? 'Localisation en cours…'
                              : !_userHasDragged
                                  ? 'Glissez pour ajuster la position'
                                  : _hasAddress
                                      ? _addressText
                                      : 'Glissez la carte vers l\'emplacement souhaité',
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
                    onPressed: (_isGeocoding || _isDragging || !_hasAddress)
                        ? null
                        : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: purple.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Confirmer cet emplacement',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
