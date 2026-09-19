import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

/// Role/color of a marker on [AppMap]. Pre-defined palette that replaces the
/// `BitmapDescriptor.hue*` constants used under Google Maps.
enum AppMapMarkerKind { delivery, pickup, driver }

/// A single marker to draw on [AppMap]. Equality is by id so the parent can
/// rebuild with a new set and only the changed markers are re-rendered.
class AppMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final AppMapMarkerKind kind;
  final String? title;

  /// Optional compass heading in degrees (0 = north, clockwise), used to
  /// rotate the marker so a moving driver visibly points the way they're
  /// heading instead of always facing the same fixed direction. Ignored for
  /// non-driver marker kinds. Null means "no rotation" (renders upright).
  final double? bearing;

  const AppMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.kind,
    this.title,
    this.bearing,
  });

  @override
  bool operator ==(Object other) =>
      other is AppMapMarker &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.kind == kind &&
      other.title == title &&
      other.bearing == bearing;

  @override
  int get hashCode =>
      Object.hash(id, latitude, longitude, kind, title, bearing);
}

/// Great-circle initial bearing from [from] to [to], in degrees (0-360,
/// 0 = north, clockwise) — the standard formula for "which way do I turn to
/// face the destination". Used to rotate the driver marker so it visibly
/// points in its direction of travel between consecutive GPS fixes.
double bearingBetween(
  ({double lat, double lng}) from,
  ({double lat, double lng}) to,
) {
  final lat1 = from.lat * (math.pi / 180);
  final lat2 = to.lat * (math.pi / 180);
  final dLng = (to.lng - from.lng) * (math.pi / 180);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final deg = math.atan2(y, x) * (180 / math.pi);
  return (deg + 360) % 360;
}

/// Imperative controls exposed to the parent of [AppMap]. Mirrors the subset
/// of the old `GoogleMapController` we used: animate camera to a point, or
/// fit a bounding box.
class AppMapController {
  _AppMapState? _state;

  void _attach(_AppMapState state) => _state = state;
  void _detach() => _state = null;

  Future<void> animateToPoint(
    double latitude,
    double longitude, {
    double? zoom,
  }) async {
    await _state?._animateToPoint(latitude, longitude, zoom: zoom);
  }

  Future<void> fitBounds(
    List<({double lat, double lng})> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) async {
    await _state?._fitBounds(points, padding: padding);
  }

  void dispose() => _detach();
}

/// On-screen size of a pin, in logical pixels. The bitmap behind it is drawn
/// at this size multiplied by the device pixel ratio, so it stays sharp.
const double _kPinLogicalSize = 48;

/// Declutters the basemap for delivery use: business/park/school points of
/// interest and transit lines are hidden, because their tappable labels compete
/// with our own pickup/delivery/driver markers for the same pixels and carry no
/// meaning in this app. Roads, road labels and place names are left intact --
/// those are what a courier actually navigates by.
const String _kMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
]
''';

/// Google Maps-backed map widget that accepts declarative markers and a single
/// optional polyline. The parent passes a fresh [markers] set and optional
/// [polyline] on each build and Google reconciles them, so there is no
/// imperative annotation syncing to do here.
class AppMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final Set<AppMapMarker> markers;
  final List<({double lat, double lng})>? polyline;
  final bool showUserLocationPuck;
  final AppMapController? controller;
  final VoidCallback? onMapReady;

  /// Area of the map obscured by the parent's own overlays (bottom sheets,
  /// floating cards). Google keeps its controls out of it and centres camera
  /// moves on what is left, so a fitted route is not hidden behind a sheet.
  final EdgeInsets contentPadding;

  /// Live traffic shading. Useful while a delivery is in progress; noise on a
  /// static "where is this address" map, so it is opt-in.
  final bool showTraffic;

  const AppMap({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialZoom = 14,
    this.markers = const {},
    this.polyline,
    this.showUserLocationPuck = false,
    this.controller,
    this.onMapReady,
    this.contentPadding = EdgeInsets.zero,
    this.showTraffic = false,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> with SingleTickerProviderStateMixin {
  gm.GoogleMapController? _map;

  /// Drives the glide between a marker's last position and its newest one,
  /// instead of the marker jumping straight to each new GPS fix. Linear (no
  /// curve) so it reads as constant motion rather than easing in/out on
  /// every ~30m hop, which would look like a stutter more than a glide.
  late final AnimationController _markerAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(() {
      if (mounted) setState(() {});
    });

  /// Per-marker id: where the current glide started and where it's headed.
  /// Absent entries mean "not animating -- render at the raw target", which
  /// is also correctly the state for a marker's very first appearance.
  final Map<String, ({double lat, double lng, double? bearing})> _animFrom = {};
  final Map<String, ({double lat, double lng, double? bearing})> _animTo = {};

  /// Rasterized pins, keyed by kind. Built once per kind and reused -- the
  /// drawing code below is unchanged from the Mapbox version, since Google
  /// Maps also takes raw PNG bytes (via BitmapDescriptor.bytes).
  final Map<AppMapMarkerKind, Uint8List> _iconCache = {};

  /// Icons resolve asynchronously but markers must be built synchronously in
  /// build(), so the decoded descriptors are cached here and a rebuild is
  /// triggered once they are ready.
  final Map<AppMapMarkerKind, gm.BitmapDescriptor> _descriptors = {};

  /// Device pixel ratio the cached descriptors were rasterized for.
  double? _descriptorRatio;

  /// Camera moves requested before the map finished creating. Google Maps
  /// throws if the controller is used too early, so the most recent request is
  /// held here and replayed from onMapCreated.
  Future<void> Function()? _pendingCameraMove;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: rasterizing needs the device pixel ratio from MediaQuery,
    // which is not available until dependencies resolve. This also re-fires if
    // the ratio changes, which is what re-cuts the bitmaps for the new density.
    _loadDescriptors();
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
    // Markers and polylines are rebuilt declaratively in build(); unlike the
    // Mapbox annotation managers there is nothing to diff or sync here, which
    // is what removes the marker-sync race the old implementation guarded
    // against with an in-flight/queued pair of flags.
    _syncMarkerAnimations(oldWidget.markers);
    _loadDescriptors();
  }

  /// Detects which markers actually moved between builds and (re)starts a
  /// glide for each. Restarting always reads the CURRENT interpolated
  /// position as the new "from" -- not the old marker's raw position -- so a
  /// fresh GPS fix arriving mid-glide redirects smoothly instead of snapping
  /// back to the previous target first.
  void _syncMarkerAnimations(Set<AppMapMarker> oldMarkers) {
    final oldById = {for (final m in oldMarkers) m.id: m};
    final newIds = {for (final m in widget.markers) m.id};
    _animFrom.removeWhere((id, _) => !newIds.contains(id));
    _animTo.removeWhere((id, _) => !newIds.contains(id));

    var anyChanged = false;
    for (final m in widget.markers) {
      final old = oldById[m.id];
      if (old == null) continue; // first appearance -- render at target, no glide
      if (old.latitude == m.latitude &&
          old.longitude == m.longitude &&
          old.bearing == m.bearing) {
        continue; // unchanged
      }
      _animFrom[m.id] = (
        lat: _lerpMarkerLat(m.id) ?? old.latitude,
        lng: _lerpMarkerLng(m.id) ?? old.longitude,
        bearing: _lerpMarkerBearing(m.id) ?? old.bearing,
      );
      _animTo[m.id] = (lat: m.latitude, lng: m.longitude, bearing: m.bearing);
      anyChanged = true;
    }
    if (anyChanged) {
      _markerAnim
        ..stop()
        ..forward(from: 0);
    }
  }

  double? _lerpMarkerLat(String id) {
    final from = _animFrom[id], to = _animTo[id];
    if (from == null || to == null) return null;
    return ui.lerpDouble(from.lat, to.lat, _markerAnim.value);
  }

  double? _lerpMarkerLng(String id) {
    final from = _animFrom[id], to = _animTo[id];
    if (from == null || to == null) return null;
    return ui.lerpDouble(from.lng, to.lng, _markerAnim.value);
  }

  /// Shortest-path angle interpolation -- lerping 350deg toward 10deg
  /// naively would sweep the long way through 180deg; this takes the 20deg
  /// route instead.
  double? _lerpMarkerBearing(String id) {
    final from = _animFrom[id]?.bearing;
    final to = _animTo[id]?.bearing;
    if (from == null || to == null) return to ?? from;
    final diff = ((to - from + 540) % 360) - 180;
    return (from + diff * _markerAnim.value + 360) % 360;
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _markerAnim.dispose();
    _map?.dispose();
    super.dispose();
  }

  /// Rasterizes any pin kind currently in use that has not been built yet.
  ///
  /// Pins are drawn at the device pixel ratio and handed to Google with their
  /// LOGICAL size, so they stay crisp on high-density screens instead of being
  /// upscaled from a fixed 96px bitmap. The cache is keyed by kind *and* ratio
  /// so moving to a different-density display re-rasterizes rather than
  /// reusing a bitmap cut for the old one.
  Future<void> _loadDescriptors() async {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    if (ratio != _descriptorRatio) {
      _descriptors.clear();
      _iconCache.clear();
      _descriptorRatio = ratio;
    }
    final needed = {for (final m in widget.markers) m.kind};
    var added = false;
    for (final kind in needed) {
      if (_descriptors.containsKey(kind)) continue;
      final bytes = await _iconFor(kind, ratio);
      _descriptors[kind] = gm.BitmapDescriptor.bytes(
        bytes,
        width: _kPinLogicalSize,
        height: _kPinLogicalSize,
      );
      added = true;
    }
    if (added && mounted) setState(() {});
  }

  Set<gm.Marker> get _markers => {
        for (final m in widget.markers)
          gm.Marker(
            markerId: gm.MarkerId(m.id),
            // Mid-glide position when one is running (see _syncMarkerAnimations),
            // else the raw target -- covers both a settled marker and one's
            // very first appearance, which never animates.
            position: gm.LatLng(
              _lerpMarkerLat(m.id) ?? m.latitude,
              _lerpMarkerLng(m.id) ?? m.longitude,
            ),
            // Falls back to the default pin until the custom bitmap is ready,
            // so a marker is never missing from the map while it rasterizes.
            icon: _descriptors[m.kind] ?? gm.BitmapDescriptor.defaultMarker,
            // Only the driver marker conveys heading. The driver badge is drawn
            // radially symmetric precisely so it can be rotated about its centre
            // without the pin tip leaving the real coordinate.
            rotation: m.kind == AppMapMarkerKind.driver
                ? (_lerpMarkerBearing(m.id) ?? m.bearing ?? 0)
                : 0,
            anchor: m.kind == AppMapMarkerKind.driver
                ? const Offset(0.5, 0.5)
                : const Offset(0.5, 1.0),
            flat: m.kind == AppMapMarkerKind.driver,
            infoWindow: m.title == null
                ? gm.InfoWindow.noText
                : gm.InfoWindow(title: m.title),
          ),
      };

  /// White casing drawn under the brand-colored line so the route reads like a
  /// layered nav route rather than a flat stroke. Google draws polylines in
  /// zIndex order, which replaces Mapbox's implicit creation order.
  Set<gm.Polyline> get _polylines {
    final line = widget.polyline;
    if (line == null || line.length < 2) return const {};
    final points = [for (final p in line) gm.LatLng(p.lat, p.lng)];
    return {
      gm.Polyline(
        polylineId: const gm.PolylineId('route_casing'),
        points: points,
        color: const Color(0xFFFFFFFF),
        width: 11,
        jointType: gm.JointType.round,
        // Rounded caps stop the casing ending in a hard rectangle at the pins.
        startCap: gm.Cap.roundCap,
        endCap: gm.Cap.roundCap,
        zIndex: 0,
      ),
      gm.Polyline(
        polylineId: const gm.PolylineId('route'),
        points: points,
        color: const Color(0xFF059669), // brand emerald
        width: 6,
        jointType: gm.JointType.round,
        startCap: gm.Cap.roundCap,
        endCap: gm.Cap.roundCap,
        zIndex: 1,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return gm.GoogleMap(
      key: const ValueKey('app_map'),
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(widget.initialLatitude, widget.initialLongitude),
        zoom: widget.initialZoom,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: widget.showUserLocationPuck,
      myLocationButtonEnabled: widget.showUserLocationPuck,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      // Keeps Google's own controls and the copyright notice clear of sheets
      // and cards the parent overlays on the map, and biases the camera so a
      // fitted route is centred in the *visible* area rather than behind them.
      padding: widget.contentPadding,
      trafficEnabled: widget.showTraffic,
      style: _kMapStyle,
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(gm.GoogleMapController map) async {
    _map = map;
    final pending = _pendingCameraMove;
    _pendingCameraMove = null;
    if (pending != null) await pending();
    if (mounted) widget.onMapReady?.call();
  }

  Future<Uint8List> _iconFor(AppMapMarkerKind kind, double ratio) async {
    final cached = _iconCache[kind];
    if (cached != null) return cached;
    final bytes = await _renderPinBytes(kind, ratio);
    _iconCache[kind] = bytes;
    return bytes;
  }

  Color _colorFor(AppMapMarkerKind kind) {
    switch (kind) {
      case AppMapMarkerKind.delivery:
        return const Color(0xFF059669); // brand emerald
      case AppMapMarkerKind.pickup:
        return const Color(0xFF6C3DE1); // brand purple (matches address picker)
      case AppMapMarkerKind.driver:
        return const Color(0xFFF59E0B); // brand amber
    }
  }

  IconData _glyphFor(AppMapMarkerKind kind) {
    switch (kind) {
      case AppMapMarkerKind.delivery:
        return Icons.home_rounded;
      case AppMapMarkerKind.pickup:
        return Icons.storefront_rounded;
      case AppMapMarkerKind.driver:
        return Icons.two_wheeler_rounded;
    }
  }

  // Rasterize a teardrop pin
  // with a glyph + soft drop shadow at runtime so we don't have to ship
  // per-density asset PNGs. Mirrors the pin style used by MapAddressPicker.
  //
  // The driver marker gets a separate, symmetric badge (see
  // _renderDriverBadgeBytes) instead of this teardrop shape: a teardrop's
  // off-center tail always has to point straight down at the exact
  // coordinate, so rotating the whole image to show heading (iconRotate)
  // would visibly swing the tail off the driver's real position. A
  // radially-symmetric badge has no such constraint.
  Future<Uint8List> _renderPinBytes(AppMapMarkerKind kind, double ratio) async {
    if (kind == AppMapMarkerKind.driver) {
      return _renderDriverBadgeBytes(ratio);
    }
    final color = _colorFor(kind);
    final glyph = _glyphFor(kind);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Everything below is laid out in a fixed 96-unit design space; scaling the
    // canvas up front renders that same artwork at device resolution without
    // touching a single coordinate.
    canvas.scale(ratio);
    const double size = 96;
    const double bubbleRadius = 26;
    const Offset bubbleCenter = Offset(size / 2, bubbleRadius + 6);

    // Soft drop shadow under the whole pin.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(size / 2, size - 10),
        width: 22,
        height: 8,
      ),
      shadowPaint,
    );

    // Teardrop tail.
    final tailPaint = Paint()..color = color;
    final tailPath = Path()
      ..moveTo(bubbleCenter.dx - 9, bubbleCenter.dy + bubbleRadius - 10)
      ..lineTo(bubbleCenter.dx, size - 16)
      ..lineTo(bubbleCenter.dx + 9, bubbleCenter.dy + bubbleRadius - 10)
      ..close();
    canvas.drawPath(tailPath, tailPaint);

    // Round bubble with white ring.
    canvas.drawCircle(bubbleCenter, bubbleRadius + 3, Paint()..color = Colors.white);
    canvas.drawCircle(bubbleCenter, bubbleRadius, Paint()..color = color);

    // Glyph, centered in the bubble.
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      bubbleCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * ratio).round(),
      (size * ratio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Radially-symmetric driver badge: white ring, amber disc, a two-wheeler
  // glyph, and a small chevron pointing "up" (north in image-space) at the
  // rim. Combined with iconRotate + MAP rotation alignment in _syncMarkers,
  // the whole badge — chevron included — turns to face the driver's actual
  // direction of travel between consecutive GPS fixes, so the customer can
  // see at a glance which way the driver is heading, not just where they are.
  Future<Uint8List> _renderDriverBadgeBytes(double ratio) async {
    const color = Color(0xFFF59E0B); // brand amber
    final glyph = _glyphFor(AppMapMarkerKind.driver);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double size = 96;
    const Offset center = Offset(size / 2, size / 2);
    const double discRadius = 26;

    // Soft glow behind the whole badge -- gives the live driver marker a bit
    // more visual weight/"presence" on the map. A true pulsing animation
    // would need re-rasterizing this bitmap every frame (icons are drawn
    // once and cached, not redrawn per-frame -- see _iconCache), which is
    // not a cheap fit for this architecture, so this is a static accent
    // rather than an animated one.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14);
    canvas.drawCircle(center, discRadius + 16, glowPaint);

    // Soft drop shadow, centered under the disc (no tail to offset it).
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    canvas.drawCircle(center, discRadius, shadowPaint);

    // Heading chevron: a small triangle just outside the white ring,
    // pointing toward image-space "up" — this is what visibly sweeps around
    // as iconRotate changes, giving the live "which way are they walking/
    // driving" cue the plain glyph alone can't provide.
    final chevronPaint = Paint()..color = color;
    final chevronTipY = center.dy - discRadius - 13;
    final chevronPath = Path()
      ..moveTo(center.dx, chevronTipY)
      ..lineTo(center.dx - 8, chevronTipY + 12)
      ..lineTo(center.dx + 8, chevronTipY + 12)
      ..close();
    canvas.drawPath(chevronPath, chevronPaint);

    // White ring + amber disc.
    canvas.drawCircle(center, discRadius + 4, Paint()..color = Colors.white);
    canvas.drawCircle(center, discRadius, Paint()..color = color);

    // Glyph, centered in the disc.
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * ratio).round(),
      (size * ratio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _animateToPoint(
    double lat,
    double lng, {
    double? zoom,
  }) async {
    final map = _map;
    if (map == null) {
      _pendingCameraMove = () => _animateToPoint(lat, lng, zoom: zoom);
      return;
    }
    await map.animateCamera(
      gm.CameraUpdate.newCameraPosition(
        gm.CameraPosition(
          target: gm.LatLng(lat, lng),
          zoom: zoom ?? widget.initialZoom,
        ),
      ),
    );
  }

  Future<void> _fitBounds(
    List<({double lat, double lng})> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) async {
    if (points.isEmpty) return;
    final map = _map;
    if (map == null) {
      _pendingCameraMove = () => _fitBounds(points, padding: padding);
      return;
    }

    // A single point has no extent: LatLngBounds requires sw <= ne on both
    // axes, and a zero-area box makes Google Maps zoom to maximum. Centre on
    // it instead.
    if (points.length == 1) {
      await _animateToPoint(points.first.lat, points.first.lng);
      return;
    }

    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final bounds = gm.LatLngBounds(
      southwest: gm.LatLng(minLat, minLng),
      northeast: gm.LatLng(maxLat, maxLng),
    );

    // CameraUpdate.newLatLngBounds takes one padding value, so use the largest
    // side to guarantee nothing is clipped.
    final pad = [padding.top, padding.left, padding.bottom, padding.right]
        .reduce((a, b) => a > b ? a : b);

    await map.animateCamera(gm.CameraUpdate.newLatLngBounds(bounds, pad));
  }
}