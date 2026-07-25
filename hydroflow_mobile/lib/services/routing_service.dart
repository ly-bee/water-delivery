import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> polylinePoints;
  final int durationSeconds;
  final double distanceMeters;
  final bool isFallback;

  const RouteResult({
    required this.polylinePoints,
    required this.durationSeconds,
    required this.distanceMeters,
    this.isFallback = false,
  });
}

class RoutingService {
  static const String _osrmBase =
      'http://router.project-osrm.org/route/v1/driving';

  static Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final url = Uri.parse(
        '$_osrmBase/${origin.longitude},${origin.latitude}'
        ';${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;

          // OSRM returns [lng, lat] — swap to LatLng(lat, lng)
          final points = (geometry['coordinates'] as List)
              .map((c) {
                final coord = c as List;
                return LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                );
              })
              .toList();

          return RouteResult(
            polylinePoints: points,
            durationSeconds: (route['duration'] as num).toInt(),
            distanceMeters: (route['distance'] as num).toDouble(),
          );
        }
      }
    } catch (_) {}

    // Fallback: straight line + rough time estimate (25 km/h)
    final distM =
        const Distance().as(LengthUnit.Meter, origin, destination);
    final durationSec = ((distM / 1000) / 25 * 3600).round();
    return RouteResult(
      polylinePoints: [origin, destination],
      durationSeconds: durationSec,
      distanceMeters: distM,
      isFallback: true,
    );
  }

  /// Human-readable ETA from seconds — returns the time portion only,
  /// e.g. "8 mins", "1 hr 20 mins".  Callers add any "Arriving in" prefix.
  static String formatDuration(int seconds) {
    if (seconds < 60) return '< 1 min';
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min${mins == 1 ? '' : 's'}';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    if (rem == 0) return '$hrs hr';
    return '$hrs hr $rem min';
  }

  /// True if the driver has moved more than 50 m from the last routing origin,
  /// meaning a route re-fetch is worthwhile.
  static bool movedEnough(LatLng? last, LatLng current) {
    if (last == null) return true;
    return const Distance().as(LengthUnit.Meter, last, current) > 50;
  }
}
