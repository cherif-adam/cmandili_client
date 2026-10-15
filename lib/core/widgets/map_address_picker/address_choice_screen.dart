import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../utils/location_service.dart';

const _purple = Color(0xFF6C3DE1);

/// Phase 1 of MapAddressPicker, top to bottom: header with back arrow,
/// "Utiliser ma position actuelle" (GPS), "ou", a search field with Google
/// Places suggestions, then the list of suggestions.
///
/// Calls [onLocationChosen] with the coordinates once the customer picks
/// the GPS position or a suggestion.
class AddressChoiceScreen extends StatefulWidget {
  final String label;
  final void Function(double lat, double lng, String address) onLocationChosen;

  const AddressChoiceScreen({
    super.key,
    required this.label,
    required this.onLocationChosen,
  });

  @override
  State<AddressChoiceScreen> createState() => _AddressChoiceScreenState();
}

class _AddressChoiceScreenState extends State<AddressChoiceScreen> {
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _ChoiceHeader(label: widget.label, topPadding: top),
          _GpsButton(isLoading: _isGpsLoading, onPressed: _useGps),
          const _OrDivider(),
          _AddressSearchField(
            controller: _searchController,
            focusNode: _focusNode,
            isSearching: _isSearching,
            onChanged: _onSearchChanged,
            onClear: () {
              _searchController.clear();
              setState(() => _suggestions = []);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _SuggestionList(
              suggestions: _suggestions,
              hasQuery: _searchController.text.isNotEmpty,
              onSelect: _selectSuggestion,
            ),
          ),
        ],
      ),
    );
  }
}

/// White header: back arrow + the picker's label ("Adresse de livraison").
class _ChoiceHeader extends StatelessWidget {
  final String label;
  final double topPadding;

  const _ChoiceHeader({required this.label, required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: topPadding + 8, left: 8, right: 16, bottom: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Purple outlined "Utiliser ma position actuelle" (a spinner while locating).
class _GpsButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GpsButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: _purple),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: const BorderSide(color: _purple),
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
    );
  }
}

/// ──── ou ────
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

/// Grey rounded search field; a small spinner while searching, a × to
/// clear once something is typed.
class _AddressSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _AddressSearchField({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        autofocus: false,
        decoration: InputDecoration(
          hintText: 'Rechercher une adresse ou un lieu…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: _purple),
          suffixIcon: isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
                  ),
                )
              : controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClear,
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
            borderSide: const BorderSide(color: _purple, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// The places found (name + full address), or a grey hint when there are
/// none.
class _SuggestionList extends StatelessWidget {
  final List<_GeocodingResult> suggestions;
  final bool hasQuery;
  final ValueChanged<_GeocodingResult> onSelect;

  const _SuggestionList({
    required this.suggestions,
    required this.hasQuery,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Center(
        child: Text(
          !hasQuery
              ? 'Tapez un nom de rue, quartier ou lieu…'
              : 'Aucun résultat',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, i) {
        final s = suggestions[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: _purple, size: 18),
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
          onTap: () => onSelect(s),
        );
      },
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
