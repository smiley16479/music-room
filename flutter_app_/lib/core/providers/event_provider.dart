import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Event Provider - manages both events AND playlists state
/// (Playlist is Event with type=LISTENING_SESSION)
class EventProvider extends ChangeNotifier {
  final EventService eventService;

  List<Event> _events = [];
  List<Event> _myEvents = [];
  Event? _currentEvent;
  List<PlaylistTrack> _currentPlaylistTracks = [];
  bool _isLoading = false;
  String? _error;

  EventProvider({required this.eventService});

  // Getters
  List<Event> get events => _events;
  List<Event> get myEvents => _myEvents;
  
  /// Get only playlists (Events with type=LISTENING_SESSION)
  List<Event> get playlists => _events.where((e) => e.isPlaylist).toList();
  List<Event> get myPlaylists => _myEvents.where((e) => e.isPlaylist).toList();
  
  /// Get only real events (not playlists)
  List<Event> get realEvents => _events.where((e) => !e.isPlaylist).toList();
  
  Event? get currentEvent => _currentEvent;
  
  /// Backward compatibility: currentPlaylist is the same as currentEvent
  Event? get currentPlaylist => _currentEvent;
  
  /// Get tracks of the current playlist
  List<PlaylistTrack> get currentPlaylistTracks => _currentPlaylistTracks;
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all events (including playlists)
  Future<void> loadEvents({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await eventService.getEvents(
        page: page,
        limit: limit,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load my events
  Future<void> loadMyEvents({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    print('Loading my events for page $page, limit $limit');
    try {
      // Récupère TOUS les events de l'utilisateur (events + playlists)
      _myEvents = await eventService.getMyEvents(
        page: page,
        limit: limit,
      );
      print('Loaded my events count: ${_myEvents.length}');
      print('Playlists in myEvents: ${_myEvents.where((e) => e.isPlaylist).length}');
    } catch (e) {
      _error = e.toString();
      print('Error loading my events: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load event details
  Future<void> loadEventDetails(String eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentEvent = await eventService.getEvent(eventId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create event
  Future<bool> createEvent({
    required String name,
    String? description,
    required DateTime eventDate,
    DateTime? eventEndDate,
    String? locationName,
    String? visibility,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final event = await eventService.createEvent(
        name: name,
        description: description,
        eventDate: eventDate,
        eventEndDate: eventEndDate,
        locationName: locationName,
        visibility: visibility,
      );
      _myEvents.add(event);
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

  /// Update event
  Future<bool> updateEvent(
    String id, {
    String? name,
    String? title,
    String? description,
    String? type,
    String? visibility,
    String? licenseType,
    bool? votingEnabled,
    String? coverImageUrl,
    double? latitude,
    double? longitude,
    int? locationRadius,
    String? locationName,
    String? votingStartTime,
    String? votingEndTime,
    DateTime? eventDate,
    DateTime? startDate,
    DateTime? endDate,
    String? playlistName,
    String? selectedPlaylistId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await eventService.updateEvent(
        id,
        name: name ?? title,
        title: title,
        description: description,
        type: type,
        visibility: visibility,
        licenseType: licenseType,
        votingEnabled: votingEnabled,
        coverImageUrl: coverImageUrl,
        latitude: latitude,
        longitude: longitude,
        locationRadius: locationRadius,
        locationName: locationName,
        votingStartTime: votingStartTime,
        votingEndTime: votingEndTime,
        eventDate: eventDate,
        startDate: startDate,
        endDate: endDate,
        playlistName: playlistName,
        selectedPlaylistId: selectedPlaylistId,
      );

      final index = _myEvents.indexWhere((e) => e.id == id);
      if (index != -1) {
        _myEvents[index] = updated;
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

  /// Delete event
  Future<bool> deleteEvent(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await eventService.deleteEvent(id);
      _myEvents.removeWhere((e) => e.id == id);
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

  // ========== PLAYLIST METHODS ==========

  /// Load all playlists
  Future<void> loadPlaylists({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final playlists = await eventService.getPlaylists(
        page: page,
        limit: limit,
      );
      // Merge with events
      for (final playlist in playlists) {
        final index = _events.indexWhere((e) => e.id == playlist.id);
        if (index == -1) {
          _events.add(playlist);
        }
      }
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
      print('Loading my playlists...');
      // Récupère les events de l'utilisateur (contient playlists + events)
      _myEvents = await eventService.getMyEvents(
        page: page,
        limit: limit,
      );
      print('Loaded events count: ${_myEvents.length}');
      print('Playlists count: ${myPlaylists.length}');
    } catch (e) {
      _error = e.toString();
      print('Error loading my playlists: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get recommended playlists
  Future<List<Event>> getRecommended({int limit = 20}) async {
    try {
      return await eventService.getRecommendedPlaylists(limit: limit);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Search playlists
  Future<List<Event>> searchPlaylists(String query, {int limit = 20}) async {
    try {
      return await eventService.searchPlaylists(query, limit: limit);
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
      _currentEvent = await eventService.getPlaylist(playlistId);
      _currentPlaylistTracks = await eventService.getPlaylistTracks(playlistId);
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
      final playlist = await eventService.createPlaylist(
        name: name,
        description: description,
        isPublic: isPublic,
      );
      _myEvents.add(playlist);
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
      final updated = await eventService.updatePlaylist(
        id,
        name: name,
        description: description,
        isPublic: isPublic,
      );

      final index = _myEvents.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _myEvents[index] = updated;
      }

      if (_currentEvent?.id == id) {
        _currentEvent = updated;
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
    return deleteEvent(id); // Same operation
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
      await eventService.addTrackToPlaylist(
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
      await eventService.removeTrackFromPlaylist(playlistId, trackId);
      _currentPlaylistTracks.removeWhere((t) => t.trackId == trackId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add participant to event/playlist
  Future<bool> addParticipant(String eventId, String userId) async {
    try {
      final updatedEvent = await eventService.addParticipant(eventId, userId);
      
      // Update current event if it's the same one
      if (_currentEvent?.id == eventId) {
        _currentEvent = updatedEvent;
      }
      
      // Update in the lists
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        _events[index] = updatedEvent;
      }
      
      final myIndex = _myEvents.indexWhere((e) => e.id == eventId);
      if (myIndex != -1) {
        _myEvents[myIndex] = updatedEvent;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove participant from event/playlist
  Future<bool> removeParticipant(String eventId, String userId) async {
    try {
      final updatedEvent = await eventService.removeParticipant(eventId, userId);
      
      // Update current event if it's the same one
      if (_currentEvent?.id == eventId) {
        _currentEvent = updatedEvent;
      }
      
      // Update in the lists
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        _events[index] = updatedEvent;
      }
      
      final myIndex = _myEvents.indexWhere((e) => e.id == eventId);
      if (myIndex != -1) {
        _myEvents[myIndex] = updatedEvent;
      }
      
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
