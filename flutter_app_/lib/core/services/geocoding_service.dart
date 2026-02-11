import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Geocoding Service - converts place names to coordinates
class GeocodingService {
  /// Convert a place name (city, address) to latitude/longitude
  /// Returns [latitude, longitude] or null if not found
  Future<Map<String, double>?> getCoordinatesFromPlace(String placeName) async {
    try {
      debugPrint('🔍 Geocoding place: $placeName');

      if (kIsWeb) {
        return await getCoordinatesFromPlaceForWeb(placeName);
      }

      if (placeName.isEmpty) {
        debugPrint('⚠️ Empty place name');
        return null;
      }

      // locationFromAddress returns a list of Placemarks
      final locations = await locationFromAddress(placeName);

      debugPrint('📍 Locations found: ${locations.length}');

      if (locations.isEmpty) {
        debugPrint('⚠️ No location found for: $placeName');
        return null;
      }

      final location = locations.first;
      final lat = location.latitude;
      final lon = location.longitude;

      debugPrint('✅ Found location: $lat, $lon');

      return {'latitude': lat, 'longitude': lon};
    } catch (e) {
      debugPrint('❌ Geocoding error: $e (${e.runtimeType})');
      return null;
    }
  }

  /// Convert a place name to coordinates using Nominatim (OpenStreetMap)
  Future<Map<String, double>?> getCoordinatesFromPlaceForWeb(
    String placeName,
  ) async {
    if (placeName.trim().isEmpty) return null;

    try {
      debugPrint('🌐 Web geocoding: $placeName');

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(placeName)}'
        '&format=json'
        '&limit=1',
      );

      final response = await http.get(
        uri,
        headers: {
          // Obligatoire selon la policy Nominatim
          'User-Agent': 'music-room-app/1.0 (contact@musicroom.app)',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return null;
      }

      final List data = jsonDecode(response.body);

      if (data.isEmpty) {
        debugPrint('⚠️ No results for $placeName');
        return null;
      }

      final result = data.first;

      return {
        'latitude': double.parse(result['lat']),
        'longitude': double.parse(result['lon']),
      };
    } catch (e) {
      debugPrint('❌ Web geocoding error: $e');
      return null;
    }
  }

  /// Get place name from coordinates (reverse geocoding)
  /// Returns place name or null if not found
  Future<String?> getPlaceFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('🔍 Reverse geocoding: $latitude, $longitude');

      // placemarkFromCoordinates returns a list of Placemarks
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      debugPrint('📍 Placemarks found: ${placemarks.length}');

      if (placemarks.isEmpty) {
        debugPrint('⚠️ No place found for coordinates');
        return null;
      }

      final placemark = placemarks.first;
      final place =
          placemark.locality ??
          placemark.administrativeArea ??
          placemark.country ??
          'Unknown';
      debugPrint('✅ Found place: $place');

      return place;
    } catch (e) {
      debugPrint('❌ Reverse geocoding error: $e (${e.runtimeType})');
      return null;
    }
  }
}
