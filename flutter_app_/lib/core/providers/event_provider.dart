import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Event Provider - manages both events AND playlists state
/// (Playlist is Event with type=playlist)
class EventProvider extends ChangeNotifier {
  final EventService eventService;
  final WebSocketService? webSocketService;

  final List<Event> _events = [];
  Event? _currentEvent;
  List<PlaylistTrack> _currentPlaylistTracks = [];
  bool _isLoading = false;
  String? _error;
  bool _createdByMeOnly = false;

  EventProvider({required this.eventService, this.webSocketService}) {
    _setupWebSocketListeners();
  }

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
        debugPrint(
          '  - ${e.name} (type: ${e.type}, isPlaylist: ${e.isPlaylist})',
        );
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
      debugPrint('❌ Error updateEvent events: $e');
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
      // Leave previous event room if any
      final previousEventId = _currentEvent?.id;
      if (previousEventId != null &&
          previousEventId != eventId &&
          webSocketService != null &&
          webSocketService!.currentEventId != null) {
        try {
          webSocketService!.leaveEvent(previousEventId);
        } catch (_) {}
      }

      _currentEvent = await eventService.getEvent(eventId);
      // Load tracks for both playlists and events (events have associated playlists)
      _currentPlaylistTracks = await eventService.getPlaylistTracks(eventId);

      // Note: Socket room joining is now handled by individual screens
      // (event-detail room or event-playlist room) for better separation
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
    return updateEvent(id, name: name, description: description);
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

    debugPrint('Adding track to playlist $playlistId: $title — $artist');
    try {
      final newTrack = await eventService.addTrackToPlaylist(
        playlistId,
        deezerId: deezerId,
        title: title,
        artist: artist,
        album: album,
        albumCoverUrl: albumCoverUrl,
        previewUrl: previewUrl,
        duration: duration,
      );

      final exists = _currentPlaylistTracks.any((t) => t.id == newTrack.id);
      if (!exists) {
        _currentPlaylistTracks.add(newTrack);
        _currentPlaylistTracks.sort((a, b) => a.position.compareTo(b.position));
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error addTrackToPlaylist: $e');
      return false;
    } finally {
      _isLoading = false;
      debugPrint('addTrackToPlaylist finished, isLoading=false');
      notifyListeners();
    }
  }

  /// Persist playlist reorder to backend
  Future<bool> persistReorder(
    String playlistId,
    List<String> playlistTrackIds,
  ) async {
    try {
      await eventService.reorderPlaylistTracks(playlistId, playlistTrackIds);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reorder tracks locally in the provider list.
  /// This updates the in-memory order and refreshes position values.
  void reorderTrack(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _currentPlaylistTracks.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _currentPlaylistTracks.length) {
      newIndex = _currentPlaylistTracks.length;
    }

    final track = _currentPlaylistTracks.removeAt(oldIndex);
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _currentPlaylistTracks.insert(insertIndex, track);

    // Rebuild list with updated position values (positions are 1-based)
    _currentPlaylistTracks = _currentPlaylistTracks.asMap().entries.map((e) {
      final idx = e.key;
      final t = e.value;
      return PlaylistTrack(
        id: t.id,
        playlistId: t.playlistId,
        trackId: t.trackId,
        position: idx + 1,
        votes: t.votes,
        trackTitle: t.trackTitle,
        trackArtist: t.trackArtist,
        trackAlbum: t.trackAlbum,
        coverUrl: t.coverUrl,
        previewUrl: t.previewUrl,
        duration: t.duration,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
      );
    }).toList();

    notifyListeners();
  }

  /// Remove a track from the local playlist list (no API call).
  /// Used when a track-ended event comes from the server and
  /// the track has already been removed on the backend.
  void removeTrackLocally(String trackId) {
    _currentPlaylistTracks.removeWhere((t) => t.trackId == trackId);
    notifyListeners();
  }

  /// Remove a track from the playlist (calls API and updates local list)
  Future<bool> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await eventService.removeTrackFromPlaylist(playlistId, trackId);
      _currentPlaylistTracks.removeWhere((t) => t.trackId == trackId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error removeTrackFromPlaylist: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
      await eventService.inviteUsers(eventId, userIds, message: message);
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

  /// Setup WebSocket listeners for real-time updates
  void _setupWebSocketListeners() {
    if (webSocketService == null) return;

    // Listen for new events created
    webSocketService!.on('event-created', (data) {
      debugPrint('📡 Event created: $data');
      if (data is Map<String, dynamic> && data['event'] != null) {
        try {
          final event = Event.fromJson(data['event'] as Map<String, dynamic>);
          // Add to list if not already present
          if (!_events.any((e) => e.id == event.id)) {
            _events.add(event);
            notifyListeners();
          }
        } catch (e) {
          debugPrint('❌ Error parsing event-created: $e');
        }
      }
    });

    // Listen for event deletions
    webSocketService!.on('event-deleted', (data) {
      debugPrint('📡 Event deleted: $data');
      if (data is Map<String, dynamic>) {
        final eventId = data['eventId'] as String?;
        if (eventId != null) {
          _events.removeWhere((e) => e.id == eventId);
          if (_currentEvent?.id == eventId) {
            _currentEvent = null;
            _currentPlaylistTracks.clear();
          }
          notifyListeners();
        }
      }
    });

    // Listen for event updates
    webSocketService!.on('event-updated', (data) {
      debugPrint('📡 Event updated: $data');
      if (data is Map<String, dynamic> && data['event'] != null) {
        try {
          final updatedEvent = Event.fromJson(
            data['event'] as Map<String, dynamic>,
          );
          final index = _events.indexWhere((e) => e.id == updatedEvent.id);
          if (index != -1) {
            _events[index] = updatedEvent;
            if (_currentEvent?.id == updatedEvent.id) {
              _currentEvent = updatedEvent;
            }
            notifyListeners();
          }
        } catch (e) {
          debugPrint('❌ Error parsing event-updated: $e');
        }
      }
    });

    // Listen for tracks added
    webSocketService!.on('track-added', (data) {
      debugPrint('📡 Track added: $data');
      if (data is Map<String, dynamic>) {
        final eventId =
            data['eventId'] as String? ?? data['playlistId'] as String?;
        if (eventId != null && _currentEvent?.id == eventId) {
          try {
            final trackMap = data['track'] as Map<String, dynamic>?;
            if (trackMap != null) {
              // Build a PlaylistTrack from websocket payload
              final newTrack = PlaylistTrack.fromJson({
                'id': trackMap['id'],
                'eventId': eventId,
                'trackId': trackMap['trackId'] ?? trackMap['id'],
                'position':
                    trackMap['position'] ?? _currentPlaylistTracks.length + 1,
                'votes': 0,
                'trackTitle': trackMap['title'],
                'trackArtist': trackMap['artist'],
                'trackAlbum': trackMap['album'],
                'coverUrl': trackMap['thumbnailUrl'] ?? trackMap['coverUrl'],
                'previewUrl': trackMap['previewUrl'],
                'duration': trackMap['duration'],
                'createdAt': trackMap['addedAt'] ?? data['timestamp'],
                'updatedAt': trackMap['addedAt'] ?? data['timestamp'],
              });

              final exists = _currentPlaylistTracks.any(
                (t) => t.id == newTrack.id,
              );
              if (!exists) {
                _currentPlaylistTracks.add(newTrack);
                _currentPlaylistTracks.sort(
                  (a, b) => a.position.compareTo(b.position),
                );
              }
              notifyListeners();
              return;
            }
          } catch (e) {
            debugPrint('❌ Error applying websocket track-added: $e');
          }

          // Fallback: reload minimal data for the playlist
          loadPlaylistDetails(eventId);
        }
      }
    });

    // Listen for tracks removed
    webSocketService!.on('track-removed', (data) {
      debugPrint('📡 Track removed: $data');
      if (data is Map<String, dynamic>) {
        final eventId =
            data['eventId'] as String? ?? data['playlistId'] as String?;
        final trackId = data['trackId'] as String?;
        if (eventId != null && _currentEvent?.id == eventId) {
          if (trackId != null) {
            _currentPlaylistTracks.removeWhere((t) => t.trackId == trackId);
            notifyListeners();
          }
        }
      }
    });

    // Listen for tracks reordered
    webSocketService!.on('tracks-reordered', (data) {
      debugPrint('📡 Tracks reordered: $data');
      if (data is Map<String, dynamic>) {
        final eventId =
            data['eventId'] as String? ?? data['playlistId'] as String?;
        final trackOrder =
            data['trackOrder'] as List<dynamic>? ??
            data['trackIds'] as List<dynamic>?;

        if (eventId != null && _currentEvent?.id == eventId) {
          if (trackOrder != null && trackOrder.isNotEmpty) {
            // Reorder tracks in-place without reloading entire page
            _reorderTracksInPlace(trackOrder.cast<String>());
          } else {
            // Fallback to reload if no track order provided
            loadPlaylistDetails(eventId);
          }
        }
      }
    });

    // Listen for queue reordered (voting system)
    webSocketService!.on('queue-reordered', (data) {
      debugPrint('📡 Queue reordered: $data');
      if (data is Map<String, dynamic>) {
        final eventId = data['eventId'] as String?;
        final trackOrder = data['trackOrder'] as List<dynamic>?;
        final trackScores = data['trackScores'] as Map<String, dynamic>?;

        if (eventId != null &&
            _currentEvent?.id == eventId &&
            trackOrder != null) {
          // Reorder tracks in-place without reloading entire page
          _reorderTracksInPlaceByVotes(trackOrder.cast<String>(), trackScores);
        }
      }
    });
  }

  /// Reorder current playlist tracks based on new order from backend
  /// This avoids a full page reload
  void _reorderTracksInPlace(List<String> newOrder) {
    if (_currentPlaylistTracks.isEmpty) return;

    // Create a map of track ID to track for quick lookup
    final trackMap = <String, PlaylistTrack>{};
    for (final track in _currentPlaylistTracks) {
      trackMap[track.id] = track;
    }

    // Reorder tracks according to new order
    final reorderedTracks = <PlaylistTrack>[];
    for (final trackId in newOrder) {
      final track = trackMap[trackId];
      if (track != null) {
        reorderedTracks.add(track);
      }
    }

    // Add any tracks that weren't in the new order (shouldn't happen, but defensive)
    for (final track in _currentPlaylistTracks) {
      if (!reorderedTracks.contains(track)) {
        reorderedTracks.add(track);
      }
    }

    _currentPlaylistTracks = reorderedTracks;
    notifyListeners();
    debugPrint('✅ Reordered ${_currentPlaylistTracks.length} tracks in-place');
  }

  /// Reorder tracks based on voting results
  /// trackOrder contains playlist track IDs in the new order
  /// trackScores contains trackId -> score mapping
  void _reorderTracksInPlaceByVotes(
    List<String> newOrder,
    Map<String, dynamic>? trackScores,
  ) {
    if (_currentPlaylistTracks.isEmpty) return;

    // Create maps for quick lookup
    final trackMapById =
        <String, PlaylistTrack>{}; // playlist track id -> track
    final trackMapByTrackId = <String, PlaylistTrack>{}; // trackId -> track

    for (final track in _currentPlaylistTracks) {
      trackMapById[track.id] = track;
      trackMapByTrackId[track.trackId] = track;
    }

    // Reorder tracks according to new order (using playlist track IDs)
    final reorderedTracks = <PlaylistTrack>[];
    int position = 1;

    for (final playlistTrackId in newOrder) {
      var track = trackMapById[playlistTrackId];

      if (track != null) {
        // Update the track with new position and vote score
        final score = trackScores?[track.trackId] as num?;
        track = PlaylistTrack(
          id: track.id,
          playlistId: track.playlistId,
          trackId: track.trackId,
          position: position,
          votes: score?.toInt() ?? track.votes,
          trackTitle: track.trackTitle,
          trackArtist: track.trackArtist,
          trackAlbum: track.trackAlbum,
          coverUrl: track.coverUrl,
          previewUrl: track.previewUrl,
          duration: track.duration,
          createdAt: track.createdAt,
          updatedAt: track.updatedAt,
        );
        reorderedTracks.add(track);
        position++;
      }
    }

    // Add any tracks that weren't in the new order (shouldn't happen, but defensive)
    for (final track in _currentPlaylistTracks) {
      final alreadyAdded = reorderedTracks.any((t) => t.id == track.id);
      if (!alreadyAdded) {
        reorderedTracks.add(
          PlaylistTrack(
            id: track.id,
            playlistId: track.playlistId,
            trackId: track.trackId,
            position: position,
            votes: track.votes,
            trackTitle: track.trackTitle,
            trackArtist: track.trackArtist,
            trackAlbum: track.trackAlbum,
            coverUrl: track.coverUrl,
            previewUrl: track.previewUrl,
            duration: track.duration,
            createdAt: track.createdAt,
            updatedAt: track.updatedAt,
          ),
        );
        position++;
      }
    }

    _currentPlaylistTracks = reorderedTracks;
    notifyListeners();
    debugPrint(
      '✅ Reordered ${_currentPlaylistTracks.length} tracks by votes in-place',
    );
  }

  @override
  void dispose() {
    // Remove WebSocket listeners
    if (webSocketService != null) {
      webSocketService!.off('event-created');
      webSocketService!.off('event-deleted');
      webSocketService!.off('event-updated');
      webSocketService!.off('track-added');
      webSocketService!.off('track-removed');
      webSocketService!.off('tracks-reordered');
      webSocketService!.off('queue-reordered');
    }
    super.dispose();
  }
}
