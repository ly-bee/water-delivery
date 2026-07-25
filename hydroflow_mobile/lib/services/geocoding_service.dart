import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  static final Map<String, LatLng?> _cache = {};

  static Future<LatLng?> getLatLng(String address) async {
    final key = address.trim().toLowerCase();
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final query = Uri.encodeComponent('$address, Juja, Kenya');
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );

      final response = await http
          .get(url, headers: {
            'User-Agent': 'AquaFlow/1.0',
            'Accept-Language': 'en',
          })
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final item = data[0] as Map<String, dynamic>;
          final lat = double.tryParse(item['lat'].toString());
          final lng = double.tryParse(item['lon'].toString());
          if (lat != null && lng != null) {
            final result = LatLng(lat, lng);
            _cache[key] = result;
            return result;
          }
        }
      }
    } catch (_) {}

    _cache[key] = null;
    return null;
  }
}
