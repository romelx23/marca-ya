import 'package:geolocator/geolocator.dart';

class Coords {
  const Coords(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

abstract class LocationService {
  /// Ubicación actual, o null si el permiso o el GPS no están disponibles.
  Future<Coords?> current();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<Coords?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));
      return Coords(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
