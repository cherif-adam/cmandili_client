import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../utils/location_service.dart';
import '../../features/checkout/data/models/delivery_address.dart';

/// Two-phase address picker modelled on Glovo/Yassir:
///
/// Phase 1 — Choice screen
///   • "Utiliser ma position actuelle" button (GPS)
///   • Search field with Mapbox Geocoding autocomplete
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

  const MapAddressPicker({super.key, required this.label});

  @override
  State<MapAddressPicker> createState() => _MapAddressPickerState();
}

class _MapAddressPickerState extends State<MapAddressPicker> {
  // ── Phase control ───────────────────────────────────────────────────────────
  bool _showMap = false;
  double _startLat = 35.6835;
  double _startLng = 10.0966;
  String _startAddress = '';

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
        label: widget.label,
        initialLatitude: _startLat,
        initialLongitude: _startLng,
        initialAddress: _startAddress,
        onBack: () => setState(() => _showMap = false),
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
    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    if (token == null || token.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
        '?access_token=$token'
        '&language=fr'
        '&limit=5'
        '&country=TN',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 && mounted) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final features = (data['features'] as List?) ?? [];
        setState(() {
          _suggestions = features
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

  factory _GeocodingResult.fromJson(Map<String, dynamic> json) {
    final coords = (json['center'] as List).cast<num>();
    return _GeocodingResult(
      text: json['text'] as String? ?? '',
      placeName: json['place_name'] as String? ?? '',
      lat: coords[1].toDouble(),
      lng: coords[0].toDouble(),
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

  const _MapFineTune({
    required this.label,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialAddress,
    required this.onBack,
  });

  @override
  State<_MapFineTune> createState() => _MapFineTuneState();
}

class _MapFineTuneState extends State<_MapFineTune>
    with SingleTickerProviderStateMixin {
  mb.MapboxMap? _map;
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
    await _map?.flyTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: 16,
      ),
      mb.MapAnimationOptions(duration: 800),
    );
    _programmaticMoveTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _isProgrammaticMove = false;
    });
  }

  void _onMapCreated(mb.MapboxMap map) {
    _map = map;
    // Fly to the pre-chosen location once the map is ready.
    _programmaticFlyTo(widget.initialLatitude, widget.initialLongitude);
  }

  void _onCameraChange(mb.CameraChangedEventData _) {
    if (!_isProgrammaticMove && !_userHasDragged) {
      setState(() => _userHasDragged = true);
    }
    if (!_isProgrammaticMove && !_isDragging) {
      setState(() => _isDragging = true);
      _pinController.forward();
    }
    _geocodeDebounce?.cancel();
  }

  void _onMapIdle(mb.MapIdleEventData _) {
    if (_isDragging) {
      setState(() => _isDragging = false);
      _pinController.reverse();
    }
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 300), _geocodeCenter);
  }

  Future<void> _geocodeCenter() async {
    final map = _map;
    if (map == null) return;
    setState(() => _isGeocoding = true);
    try {
      final state = await map.getCameraState();
      final lat = state.center.coordinates.lat.toDouble();
      final lng = state.center.coordinates.lng.toDouble();
      _currentLat = lat;
      _currentLng = lng;
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
          mb.MapWidget(
            cameraOptions: mb.CameraOptions(
              center: mb.Point(
                coordinates: mb.Position(_currentLng, _currentLat),
              ),
              zoom: 16,
            ),
            styleUri: mb.MapboxStyles.MAPBOX_STREETS,
            onMapCreated: _onMapCreated,
            onCameraChangeListener: _onCameraChange,
            onMapIdleListener: _onMapIdle,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 20),
                        const SizedBox(width: 8),
                        const Text(
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
