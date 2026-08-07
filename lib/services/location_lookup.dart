import 'package:geolocator/geolocator.dart';

/// A resolved user position (lat/lng only — we don't need accuracy/heading
/// for distance filtering).
class UserPosition {
  final double lat;
  final double lng;

  const UserPosition({required this.lat, required this.lng});
}

/// Wraps `geolocator` behind an injectable function so tests can supply a
/// fixed position without real device GPS/permissions (mirrors the
/// `Random? random` seam already used in `ActivityRecommender`).
class LocationLookup {
  /// Requests permission (if needed) and returns the current position, or
  /// null if permission was denied or location services are off/unavailable.
  /// Never throws — all failure modes collapse to null so the caller can
  /// fall back to "no distance filter" rather than crashing.
  static Future<UserPosition?> getCurrentPosition() async {
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));
      return UserPosition(lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
