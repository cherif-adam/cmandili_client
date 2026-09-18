import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  // Check and request location permissions
  static Future<bool> checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  // Get current position
  static Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }
    
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      return null;
    }
    
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }
  
  // Get address from coordinates
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }
  
  // Get coordinates from address
  static Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Calculate distance between two points in kilometers (Haversine fallback)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Builds a Google Directions request. Note the coordinate order differs
  /// from Mapbox: Google takes `lat,lng` while Mapbox took `lng,lat`.
  static Uri? _directionsUri(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) return null;
    return Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$lat1,$lon1&destination=$lat2,$lon2&mode=driving&key=$key',
    );
  }

  /// Sums the per-leg values of a Google Directions route. Unlike Mapbox,
  /// which reports `routes[0].distance` / `.duration` at the route level,
  /// Google only reports these per leg, so they must be added up.
  static num? _sumLegs(Map<String, dynamic> data, String field) {
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final legs = routes.first['legs'];
    if (legs is! List || legs.isEmpty) return null;
    num total = 0;
    for (final leg in legs) {
      final v = leg[field]?['value'];
      if (v is! num) return null;
      total += v;
    }
    return total;
  }

  // Calculate real route distance using the Google Directions API.
  static Future<double> calculateRouteDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    final url = _directionsUri(lat1, lon1, lat2, lon2);
    if (url == null) return calculateDistance(lat1, lon1, lat2, lon2);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Google returns HTTP 200 even for REQUEST_DENIED / ZERO_RESULTS, so
        // the payload status has to be checked rather than the status code.
        if (data['status'] == 'OK') {
          final meters = _sumLegs(data, 'distance');
          if (meters != null) return meters.toDouble() / 1000;
        }
      }
      return calculateDistance(lat1, lon1, lat2, lon2);
    } catch (e) {
      return calculateDistance(lat1, lon1, lat2, lon2);
    }
  }

  /// Same Directions API call as [calculateRouteDistance], but also keeps the
  /// `duration` field that call already receives and discards — used to seed
  /// `orders.estimated_delivery_time` at checkout. A separate function
  /// (rather than changing calculateRouteDistance's return type) so the
  /// delivery-fee path — real money, already relied on — is untouched.
  /// Returns null (no estimate) wherever the distance-only path would have
  /// silently fallen back to Haversine, since straight-line distance carries
  /// no duration.
  static Future<int?> estimateRouteDurationSeconds(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    final url = _directionsUri(lat1, lon1, lat2, lon2);
    if (url == null) return null;

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final seconds = _sumLegs(data, 'duration');
          if (seconds != null) return seconds.round();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
