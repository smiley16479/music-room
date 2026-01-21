import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Playlist Provider - manages playlist state
class PlaylistProvider extends ChangeNotifier {
  final PlaylistService playlistService;

  List<Playlist> _playlists = [];
  List<Playlist> _myPlaylists = [];
  Playlist? _currentPlaylist;
  List<PlaylistTrack> _currentPlaylistTracks = [];
  bool _isLoading = false;
  String? _error;

  PlaylistProvider({required this.playlistService});

  // Getters
  List<Playlist> get playlists => _playlists;
  List<Playlist> get myPlaylists => _myPlaylists;
  Playlist? get currentPlaylist => _currentPlaylist;
  List<PlaylistTrack> get currentPlaylistTracks => _currentPlaylistTracks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all playlists
  Future<void> loadPlaylists({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _playlists = await playlistService.getPlaylists(
        page: page,
        limit: limit,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load my playlists
  Future<void> loadMyPlaylists({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _myPlaylists = await playlistService.getMyPlaylists(
        page: page,
        limit: limit,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get recommended playlists
  Future<List<Playlist>> getRecommended({int limit = 20}) async {
    try {
      return await playlistService.getRecommendedPlaylists(limit: limit);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Search playlists
  Future<List<Playlist>> searchPlaylists(String query, {int limit = 20}) async {
    try {
      return await playlistService.searchPlaylists(query, limit: limit);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Load playlist details
  Future<void> loadPlaylistDetails(String playlistId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentPlaylist = await playlistService.getPlaylist(playlistId);
      _currentPlaylistTracks =
          await playlistService.getPlaylistTracks(playlistId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create playlist
  Future<bool> createPlaylist({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final playlist = await playlistService.createPlaylist(
        name: name,
        description: description,
        isPublic: isPublic,
      );
      _myPlaylists.add(playlist);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update playlist
  Future<bool> updatePlaylist(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await playlistService.updatePlaylist(
        id,
        name: name,
        description: description,
        isPublic: isPublic,
      );

      final index = _myPlaylists.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _myPlaylists[index] = updated;
      }

      if (_currentPlaylist?.id == id) {
        _currentPlaylist = updated;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete playlist
  Future<bool> deletePlaylist(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await playlistService.deletePlaylist(id);
      _myPlaylists.removeWhere((p) => p.id == id);

      if (_currentPlaylist?.id == id) {
        _currentPlaylist = null;
        _currentPlaylistTracks = [];
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Add track to playlist
  Future<bool> addTrackToPlaylist(
    String playlistId, {
    required String deezerId,
    required String title,
    required String artist,
    required String album,
    String? albumCoverUrl,
    String? previewUrl,
    int? duration,
  }) async {
    try {
      await playlistService.addTrackToPlaylist(
        playlistId,
        deezerId: deezerId,
        title: title,
        artist: artist,
        album: album,
        albumCoverUrl: albumCoverUrl,
        previewUrl: previewUrl,
        duration: duration,
      );
      await loadPlaylistDetails(playlistId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove track from playlist
  Future<bool> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    try {
      await playlistService.removeTrackFromPlaylist(playlistId, trackId);
      _currentPlaylistTracks.removeWhere((t) => t.trackId == trackId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
