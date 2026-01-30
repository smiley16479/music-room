import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Event Provider - manages both events AND playlists state
/// (Playlist is Event with type=playlist)
class EventProvider extends ChangeNotifier {
  final EventService eventService;

  final List<Event> _events = [];
  Event? _currentEvent;
  List<PlaylistTrack> _currentPlaylistTracks = [];
  bool _isLoading = false;
  String? _error;
  bool _createdByMeOnly = false;

  EventProvider({required this.eventService});

  // Getters
  /// All events (user's + public), unfiltered
  List<Event> get allEvents => _events;

  /// Events filtered by _createdByMeOnly flag
  List<Event> get events => _createdByMeOnly
      ? _events.where((e) => e.isCreatedByMe).toList()
      : _events;

  /// Get only playlists (for backward compatibility)
  List<Event> get playlists => events.where((e) => e.isPlaylist).toList();

  /// Get only my playlists (alias for playlists) ⚠️ semble juste redonner playlists
  List<Event> get myPlaylists => playlists;

  /// Get only real events (not playlists) filtered by _createdByMeOnly
  List<Event> get realEvents => events.where((e) => !e.isPlaylist).toList();

  /// Legacy getter for backward compatibility
  List<Event> get myEvents => events;

  Event? get currentEvent => _currentEvent;

  /// Backward compatibility: currentPlaylist is the same as currentEvent
  Event? get currentPlaylist => _currentEvent;

  /// Get tracks of the current playlist
  List<PlaylistTrack> get currentPlaylistTracks => _currentPlaylistTracks;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get createdByMeOnly => _createdByMeOnly;

  /// Load all events: combines user's events (scope='my') + public events (scope='all')
  /// By default shows both, but can be filtered via setCreatedByMeOnly()
  Future<void> loadEvents({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load user's events first
      final myEvents = await eventService.getMyEvents(page: page, limit: limit);
      
      // Load public events (scope='all') - accessible to everyone
      final publicEvents = await eventService.getEvents(
        page: page,
        limit: limit,
      );
      
      // Merge both lists, avoiding duplicates
      _events.clear();
      _events.addAll(myEvents);
      for (var event in publicEvents) {
        if (!_events.any((e) => e.id == event.id)) {
          _events.add(event);
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading events: $e');
    }

    _isLoading = false;
    notifyListeners();
  }



  /// Load my events (all types)
  /// The UI will filter using myPlaylists or realEvents getters
  Future<void> loadMyEvents({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    debugPrint('Loading my events for page $page, limit $limit');
    try {
      // Récupère TOUS les events de l'utilisateur (events + playlists)
      final myEvents = await eventService.getMyEvents(page: page, limit: limit);
      _events.clear();
      _events.addAll(myEvents);
      debugPrint('✅ Loaded my events count: ${_events.length}');
      debugPrint('📋 Event details:');
      for (var e in _events) {
        debugPrint('  - ${e.name} (type: ${e.type}, isPlaylist: ${e.isPlaylist})');
      }
      debugPrint(
        '🎵 Playlists: ${myPlaylists.length}, 🎉 Real Events: ${realEvents.length}',
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading my events: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create event
  Future<bool> createEvent({
    required String name,
    String? description,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? locationName,
    String? visibility,
    String? type,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    debugPrint('Creating event - Type: $type, Name: $name');
    try {
      final event = await eventService.createEvent(
        name: name,
        description: description,
        eventDate: eventDate,
        eventEndDate: eventEndDate,
        locationName: locationName,
        visibility: visibility,
        type: type,
      );
      debugPrint(
        'Event created successfully - ID: ${event.id}, Type: ${event.type}',
      );
      _events.add(event);
      debugPrint('Total events in provider: ${_events.length}');
      debugPrint(
        'Playlists: ${myPlaylists.length}, Real Events: ${realEvents.length}',
      );
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
        longitude: longitude,
        locationRadius: locationRadius,
        locationName: locationName,
        votingStartTime: votingStartTime,
        eventDate: eventDate,
        startDate: startDate,
        endDate: endDate,
        playlistName: playlistName,
        selectedPlaylistId: selectedPlaylistId,
      );

      final index = _events.indexWhere((e) => e.id == id);
      if (index != -1) {
        _events[index] = updated;
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
      _events.removeWhere((e) => e.id == id);
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

  /// Remove duplicate loadPlaylists - use loadEvents() instead
  /// This method is deprecated and will be removed in next refactor
  Future<void> loadPlaylists({int page = 1, int limit = 20}) async {
    return loadEvents(page: page, limit: limit);
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

  /// Load event details (works for both events and playlists)
  Future<void> loadEventDetails(String eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentEvent = await eventService.getEvent(eventId);
      // Load tracks for both playlists and events (events have associated playlists)
      _currentPlaylistTracks = await eventService.getPlaylistTracks(eventId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load playlist details (deprecated - use loadEventDetails instead)
  Future<void> loadPlaylistDetails(String playlistId) async {
    return loadEventDetails(playlistId);
  }

  /// Create playlist (works same as createEvent with type='playlist')
  /// Get track by id
  Future<bool> getTrackById(String trackId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final track = await eventService.getTrackById(trackId);
      _currentPlaylistTracks = [track];
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

  /// Create playlist
  Future<bool> createPlaylist({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    return createEvent(
      name: name,
      description: description,
      visibility: isPublic ? 'public' : 'private',
      type: 'playlist',
    );
  }

  /// Update playlist (delegates to updateEvent)
  Future<bool> updatePlaylist(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    String? eventLicenseType,
  }) async {
    return updateEvent(
      id,
      name: name,
      description: description,
    );
  }

  /// Delete playlist (same as deleteEvent)
  Future<bool> deletePlaylist(String id) async {
    return deleteEvent(id);
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
    _isLoading = true;
    _error = null;
    notifyListeners();

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
      // Reload playlist details to get the updated track list
      await loadPlaylistDetails(playlistId);
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
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

  /// Reorder track in playlist (local only - call persistReorder to save)
  void reorderTrack(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _currentPlaylistTracks.length ||
        newIndex < 0 || newIndex > _currentPlaylistTracks.length) {
      return;
    }

    // Remove the item from the old position
    final track = _currentPlaylistTracks.removeAt(oldIndex);
    
    // Insert at the new position
    _currentPlaylistTracks.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, track);
    
    notifyListeners();
  }

  /// Persist playlist reorder to backend
  Future<bool> persistReorder(String playlistId, List<String> playlistTrackIds) async {
    try {
      await eventService.reorderPlaylistTracks(playlistId, playlistTrackIds);
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
      final updatedEvent = await eventService.removeParticipant(
        eventId,
        userId,
      );

      // Update current event if it's the same one
      if (_currentEvent?.id == eventId) {
        _currentEvent = updatedEvent;
      }

      // Update in the lists
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        _events[index] = updatedEvent;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Invite users to an event (creates invitations instead of adding as direct participants)
  /// This is the correct method for inviting friends to private events
  Future<bool> inviteUsers(
    String eventId,
    List<String> userIds, {
    String? message,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await eventService.inviteUsers(
        eventId,
        userIds,
        message: message,
      );
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

  /// Toggle "Created by me" filter
  /// When true: only shows events/playlists created by the user
  /// When false: shows all events/playlists (user's + public)
  void setCreatedByMeOnly(bool value) {
    _createdByMeOnly = value;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
