import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

/// Periodically reports the driver's GPS position to the HydroFlow backend.
/// Call [startTracking] when the driver goes online; [stopTracking] when offline.
class LocationService {
  static Timer?  _timer;
  static bool    _tracking = false;
  static bool    _foregroundOnly = false; // set true when background denied

  static bool get isTracking    => _tracking;
  static bool get foregroundOnly => _foregroundOnly;

  // ── permission ─────────────────────────────────────────────────────────

  /// Returns true if we have at least foreground location permission.
  static Future<bool> requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      return false;
    }

    // Background permission is a bonus — fall back gracefully if unavailable
    if (perm == LocationPermission.whileInUse) {
      _foregroundOnly = true;
    }

    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  // ── tracking ────────────────────────────────────────────────────────────

  /// Starts sending location every 10 seconds while driver is active.
  /// Returns false if permission was denied.
  static Future<bool> startTracking() async {
    if (_tracking) return true;

    final granted = await requestPermission();
    if (!granted) return false;

    _tracking = true;
    _foregroundOnly = false;

    // Send once immediately, then on every interval tick
    await _sendLocation();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_tracking) return;
      await _sendLocation();
    });

    return true;
  }

  static void stopTracking() {
    _tracking = false;
    _timer?.cancel();
    _timer = null;
  }

  // ── internal ─────────────────────────────────────────────────────────

  static Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      await ApiService.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // silently skip — next tick will retry
    }
  }
}
