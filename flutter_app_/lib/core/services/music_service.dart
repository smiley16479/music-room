import '../models/track_search_result.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'api_service.dart';

/// Music Service - Search tracks from Deezer
/// Note: Spotify integration is not yet implemented on the backend
class MusicService {
  final ApiService apiService;

  MusicService({required this.apiService});

  /// Search tracks on Deezer
  Future<List<TrackSearchResult>> searchDeezer(String query) async {
    try {
      final response = await apiService.get(
        '/music/deezer/search?q=${Uri.encodeComponent(query)}',
      );

      List<dynamic> tracks;
      if (response is Map<String, dynamic>) {
        if (response.containsKey('data')) {
          tracks = response['data'] as List;
        } else {
          tracks = [];
        }
      } else if (response is List) {
        tracks = response;
      } else {
        tracks = [];
      }

      return tracks
          .map((track) => TrackSearchResult.fromDeezerJson(track as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error searching Deezer: $e');
      return [];
    }
  }

  /// Search all available music sources (currently only Deezer)
  Future<List<TrackSearchResult>> searchAll(String query) async {
    return searchDeezer(query);
  }
}
