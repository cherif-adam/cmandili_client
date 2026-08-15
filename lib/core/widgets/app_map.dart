import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

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

  const AppMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.kind,
    this.title,
  });

  @override
  bool operator ==(Object other) =>
      other is AppMapMarker &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.kind == kind &&
      other.title == title;

  @override
  int get hashCode => Object.hash(id, latitude, longitude, kind, title);
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

/// Mapbox-backed map widget that accepts declarative markers and a single
/// optional polyline. Drop-in replacement for the previous `GoogleMap` usage:
/// the parent passes a fresh [markers] set and optional [polyline] on each
/// build, we diff against what's currently rendered, and update the
/// annotation managers accordingly.
class AppMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final Set<AppMapMarker> markers;
  final List<({double lat, double lng})>? polyline;
  final bool showUserLocationPuck;
  final AppMapController? controller;
  final VoidCallback? onMapReady;

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
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  mb.MapboxMap? _map;
  mb.PointAnnotationManager? _markerManager;
  mb.PolylineAnnotationManager? _polylineManager;

  final Map<String, mb.PointAnnotation> _renderedMarkers = {};
  mb.PolylineAnnotation? _renderedPolyline;
  mb.PolylineAnnotation? _renderedPolylineCasing;

  final Map<AppMapMarkerKind, Uint8List> _iconCache = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
    if (_map != null) {
      if (widget.markers != oldWidget.markers) {
        _syncMarkers();
      }
      if (widget.polyline != oldWidget.polyline) {
        _syncPolyline();
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return mb.MapWidget(
      key: const ValueKey('app_map'),
      cameraOptions: mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(
            widget.initialLongitude,
            widget.initialLatitude,
          ),
        ),
        zoom: widget.initialZoom,
      ),
      styleUri: mb.MapboxStyles.LIGHT,
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _map = map;
    if (widget.showUserLocationPuck) {
      await map.location.updateSettings(
        mb.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
        ),
      );
    }
    _markerManager = await map.annotations.createPointAnnotationManager();
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
    await _syncMarkers();
    await _syncPolyline();
    if (mounted) widget.onMapReady?.call();
  }

  Future<void> _syncMarkers() async {
    final manager = _markerManager;
    if (manager == null) return;

    final incoming = {for (final m in widget.markers) m.id: m};

    final toRemove = <String>[];
    for (final id in _renderedMarkers.keys) {
      if (!incoming.containsKey(id)) toRemove.add(id);
    }
    for (final id in toRemove) {
      final ann = _renderedMarkers.remove(id);
      if (ann != null) await manager.delete(ann);
    }

    for (final marker in incoming.values) {
      final existing = _renderedMarkers[marker.id];
      final icon = await _iconFor(marker.kind);
      final point = mb.Point(
        coordinates: mb.Position(marker.longitude, marker.latitude),
      );
      if (existing == null) {
        final ann = await manager.create(
          mb.PointAnnotationOptions(
            geometry: point,
            image: icon,
            iconSize: 1.0,
            iconAnchor: mb.IconAnchor.BOTTOM,
            textField: marker.title,
            textOffset: [0, 0.6],
            textSize: 12,
            textColor: 0xFF2D3436,
            textHaloColor: 0xFFFFFFFF,
            textHaloWidth: 1.5,
            textAnchor: mb.TextAnchor.TOP,
          ),
        );
        _renderedMarkers[marker.id] = ann;
      } else {
        existing.geometry = point;
        existing.textField = marker.title;
        await manager.update(existing);
      }
    }
  }

  Future<void> _syncPolyline() async {
    final manager = _polylineManager;
    if (manager == null) return;

    final line = widget.polyline;
    if (line == null || line.length < 2) {
      final existingCasing = _renderedPolylineCasing;
      if (existingCasing != null) {
        await manager.delete(existingCasing);
        _renderedPolylineCasing = null;
      }
      final existing = _renderedPolyline;
      if (existing != null) {
        await manager.delete(existing);
        _renderedPolyline = null;
      }
      return;
    }

    final geometry = mb.LineString(
      coordinates: [
        for (final p in line) mb.Position(p.lng, p.lat),
      ],
    );

    // White casing drawn first so the brand-colored line on top reads like a
    // layered nav route rather than a flat stroke.
    final existingCasing = _renderedPolylineCasing;
    if (existingCasing == null) {
      _renderedPolylineCasing = await manager.create(
        mb.PolylineAnnotationOptions(
          geometry: geometry,
          lineColor: 0xFFFFFFFF,
          lineWidth: 8.0,
          lineJoin: mb.LineJoin.ROUND,
        ),
      );
    } else {
      existingCasing.geometry = geometry;
      await manager.update(existingCasing);
    }

    final existing = _renderedPolyline;
    if (existing == null) {
      _renderedPolyline = await manager.create(
        mb.PolylineAnnotationOptions(
          geometry: geometry,
          lineColor: 0xFF059669, // brand emerald
          lineWidth: 5.0,
          lineJoin: mb.LineJoin.ROUND,
        ),
      );
    } else {
      existing.geometry = geometry;
      await manager.update(existing);
    }
  }

  Future<Uint8List> _iconFor(AppMapMarkerKind kind) async {
    final cached = _iconCache[kind];
    if (cached != null) return cached;
    final bytes = await _renderPinBytes(kind);
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
        return Icons.delivery_dining_rounded;
    }
  }

  // Mapbox's PointAnnotation needs raw PNG bytes; rasterize a teardrop pin
  // with a glyph + soft drop shadow at runtime so we don't have to ship
  // per-density asset PNGs. Mirrors the pin style used by MapAddressPicker.
  Future<Uint8List> _renderPinBytes(AppMapMarkerKind kind) async {
    final color = _colorFor(kind);
    final glyph = _glyphFor(kind);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double size = 96;
    const double bubbleRadius = 26;
    const Offset bubbleCenter = Offset(size / 2, bubbleRadius + 6);

    // Soft drop shadow under the whole pin.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size / 2, size - 10),
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
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _animateToPoint(
    double lat,
    double lng, {
    double? zoom,
  }) async {
    await _map?.flyTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: zoom,
      ),
      mb.MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _fitBounds(
    List<({double lat, double lng})> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) async {
    final map = _map;
    if (map == null || points.isEmpty) return;
    final coords = [
      for (final p in points) mb.Point(coordinates: mb.Position(p.lng, p.lat)),
    ];
    final cam = await map.cameraForCoordinatesPadding(
      coords,
      mb.CameraOptions(),
      mb.MbxEdgeInsets(
        top: padding.top,
        left: padding.left,
        bottom: padding.bottom,
        right: padding.right,
      ),
      null,
      null,
    );
    await map.flyTo(cam, mb.MapAnimationOptions(duration: 600));
  }
}
