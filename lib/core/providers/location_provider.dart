import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/location_service.dart';

final locationProvider = StateNotifierProvider<LocationNotifier, String>((ref) {
  return LocationNotifier();
});

class LocationNotifier extends StateNotifier<String> {
  LocationNotifier() : super('Current Location') {
    _initLocation();
  }

  Future<void> _initLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      final address = await LocationService.getAddressFromCoordinates(position.latitude, position.longitude);
      if (mounted) {
        state = address;
      }
    }
  }

  Future<void> refreshLocation() async {
    state = 'Locating...';
    await _initLocation();
  }
}
