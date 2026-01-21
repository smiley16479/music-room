import '../../config/app_config.dart';
import '../models/index.dart';
import 'api_service.dart';

/// Playlist Service - manages playlist operations
class PlaylistService {
  final ApiService apiService;

  PlaylistService({required this.apiService});

  /// Get all playlists
  Future<List<Playlist>> getPlaylists({
    int page = 1,
    int limit = 20,
    bool? isPublic,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (isPublic != null) 'isPublic': isPublic.toString(),
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    final endpoint = '${AppConfig.playlistsEndpoint}?$queryString';
    final response = await apiService.get(endpoint);

    final data = response['data'] as List;
    return data.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Get my playlists
  Future<List<Playlist>> getMyPlaylists({
    int page = 1,
    int limit = 20,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    final endpoint = '${AppConfig.playlistsEndpoint}/my-playlists?$queryString';
    final response = await apiService.get(endpoint);

    final data = response['data'] as List;
    return data.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Get recommended playlists
  Future<List<Playlist>> getRecommendedPlaylists({int limit = 20}) async {
    final endpoint = '${AppConfig.playlistsEndpoint}/recommended?limit=$limit';
    final response = await apiService.get(endpoint);

    final data = response['data'] as List;
    return data.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Search playlists
  Future<List<Playlist>> searchPlaylists(
    String query, {
    int limit = 20,
  }) async {
    final endpoint = '${AppConfig.playlistsEndpoint}/search?q=$query&limit=$limit';
    final response = await apiService.get(endpoint);

    final data = response as List;
    return data.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Get playlist by ID
  Future<Playlist> getPlaylist(String id) async {
    final response = await apiService.get('${AppConfig.playlistsEndpoint}/$id');
    final data = response['data'] as Map<String, dynamic>;
    return Playlist.fromJson(data);
  }

  /// Create new playlist
  Future<Playlist> createPlaylist({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    final response = await apiService.post(
      AppConfig.playlistsEndpoint,
      body: {
        'name': name,
        if (description != null) 'description': description,
        'visibility': isPublic ? 'public' : 'private',
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    return Playlist.fromJson(data);
  }

  /// Update playlist
  Future<Playlist> updatePlaylist(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    final response = await apiService.patch(
      '${AppConfig.playlistsEndpoint}/$id',
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isPublic != null) 'visibility': isPublic ? 'public' : 'private',
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    return Playlist.fromJson(data);
  }

  /// Delete playlist
  Future<void> deletePlaylist(String id) async {
    await apiService.delete('${AppConfig.playlistsEndpoint}/$id');
  }

  /// Get playlist tracks
  Future<List<PlaylistTrack>> getPlaylistTracks(String playlistId) async {
    final response = await apiService.get(
      '${AppConfig.playlistsEndpoint}/$playlistId/tracks',
    );

    final data = response['data'] as List;
    return data
        .map((t) => PlaylistTrack.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Add track to playlist
  Future<PlaylistTrack> addTrackToPlaylist(
    String playlistId, {
    required String deezerId,
    required String title,
    required String artist,
    required String album,
    String? albumCoverUrl,
    String? previewUrl,
    int? duration,
  }) async {
    final response = await apiService.post(
      '${AppConfig.playlistsEndpoint}/$playlistId/tracks',
      body: {
        'deezerId': deezerId,
        'title': title,
        'artist': artist,
        'album': album,
        if (albumCoverUrl != null) 'albumCoverUrl': albumCoverUrl,
        if (previewUrl != null) 'previewUrl': previewUrl,
        if (duration != null) 'duration': duration,
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    return PlaylistTrack.fromJson(data);
  }

  /// Remove track from playlist
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    await apiService.delete(
      '${AppConfig.playlistsEndpoint}/$playlistId/tracks/$trackId',
    );
  }

  /// Get playlist collaborators
  Future<List<User>> getCollaborators(String playlistId) async {
    final response = await apiService.get(
      '${AppConfig.playlistsEndpoint}/$playlistId/collaborators',
    );

    final data = response['data'] as List;
    return data.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
  }

  /// Invite collaborators to playlist
  Future<void> inviteToPlaylist(
    String playlistId, {
    required List<String> userIds,
    String? message,
  }) async {
    await apiService.post(
      '${AppConfig.playlistsEndpoint}/$playlistId/invite',
      body: {
        'userIds': userIds,
        if (message != null) 'message': message,
      },
    );
  }

  /// Duplicate playlist
  Future<Playlist> duplicatePlaylist(
    String playlistId, {
    String? newName,
  }) async {
    final response = await apiService.post(
      '${AppConfig.playlistsEndpoint}/$playlistId/duplicate',
      body: {
        if (newName != null) 'name': newName,
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    return Playlist.fromJson(data);
  }
}
