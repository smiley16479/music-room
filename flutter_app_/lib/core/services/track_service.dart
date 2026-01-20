import '../models/index.dart';
import 'api_service.dart';

/// Track Service - manages track operations
class TrackService {
  final ApiService apiService;

  TrackService({required this.apiService});

  /// Search tracks
  Future<List<Track>> searchTracks(String query) async {
    final response = await apiService.get('/tracks/search?q=$query');
    final data = response['data'] as List;
    return data.map((t) => Track.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Get track by ID
  Future<Track> getTrack(String id) async {
    final response = await apiService.get('/tracks/$id');
    final data = response['data'] as Map<String, dynamic>;
    return Track.fromJson(data);
  }

  /// Vote for track (move up in playlist)
  Future<void> voteForTrack(String playlistId, String trackId) async {
    await apiService.post(
      '/playlists/$playlistId/tracks/$trackId/vote',
    );
  }
}
