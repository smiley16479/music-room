import '../../config/app_config.dart';
import '../models/index.dart';
import 'api_service.dart';

/// Event Service - manages event operations
class EventService {
  final ApiService apiService;

  EventService({required this.apiService});

  /// Get all events
  Future<List<Event>> getEvents({int page = 1, int limit = 20}) async {
    final params = {'page': page.toString(), 'limit': limit.toString()};

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final endpoint = '${AppConfig.eventsEndpoint}?$queryString';
    final response = await apiService.get(endpoint);

    // Handle both wrapped response (with 'data' field) and direct data response
    List<dynamic> dataList;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      dataList = response['data'] as List;
    } else if (response is List) {
      dataList = response;
    } else {
      throw Exception(
        'Invalid response format: expected List but got ${response.runtimeType}',
      );
    }

    return dataList
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get my events
  Future<List<Event>> getMyEvents({int page = 1, int limit = 20}) async {
    final params = {
      'page': page.toString(),
      'limit': limit.toString(),
      'scope': 'my', // Use unified endpoint with scope parameter
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final endpoint = '${AppConfig.eventsEndpoint}?$queryString';
    final response = await apiService.get(endpoint);

    // Handle both wrapped response (with 'data' field) and direct data response
    List<dynamic> dataList;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      dataList = response['data'] as List;
    } else if (response is List) {
      dataList = response;
    } else {
      throw Exception(
        'Invalid response format: expected List but got ${response.runtimeType}',
      );
    }

    return dataList
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get event by ID
  Future<Event> getEvent(String id) async {
    final response = await apiService.get('${AppConfig.eventsEndpoint}/$id');

    print('Get event response: $response');
    print('Response type: ${response.runtimeType}');

    // Handle both wrapped response (with 'data' field) and direct data response
    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception(
        'Invalid response format: expected Map but got ${response.runtimeType}',
      );
    }

    try {
      return Event.fromJson(eventData);
    } catch (e) {
      print('Error parsing Event.fromJson for getEvent: $e');
      print('Event data: $eventData');
      rethrow;
    }
  }

  /// Create new event
  Future<Event> createEvent({
    required String name,
    String? description,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? locationName,
    String? visibility,
    String? type,
  }) async {
    final response = await apiService.post(
      AppConfig.eventsEndpoint,
      body: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (eventDate != null) 'eventDate': eventDate.toIso8601String(),
        if (eventEndDate != null)
          'eventEndDate': eventEndDate.toIso8601String(),
        if (locationName != null && locationName.isNotEmpty)
          'locationName': locationName,
        if (visibility != null) 'visibility': visibility,
        if (type != null) 'type': type,
      },
    );

    print('Event creation response: $response');
    print('Response type: ${response.runtimeType}');

    // Handle both wrapped response (with 'data' field) and direct data response
    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception(
        'Invalid response format: expected Map but got ${response.runtimeType}',
      );
    }

    try {
      return Event.fromJson(eventData);
    } catch (e) {
      print('Error parsing Event.fromJson: $e');
      print('Event data: $eventData');
      rethrow;
    }
  }

  /// Update event
  Future<Event> updateEvent(
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
    final body = <String, dynamic>{};

    // Map 'title' to 'name' for backend compatibility
    if (name != null) body['name'] = name;
    if (title != null) body['name'] = title; // Support both title and name
    if (description != null) body['description'] = description;
    if (type != null) body['type'] = type;
    if (visibility != null) body['visibility'] = visibility;
    if (licenseType != null) body['licenseType'] = licenseType;
    if (votingEnabled != null) body['votingEnabled'] = votingEnabled;
    if (coverImageUrl != null) body['coverImageUrl'] = coverImageUrl;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (locationRadius != null) body['locationRadius'] = locationRadius;
    if (locationName != null) body['locationName'] = locationName;
    if (votingStartTime != null) body['votingStartTime'] = votingStartTime;
    if (votingEndTime != null) body['votingEndTime'] = votingEndTime;
    if (eventDate != null) body['eventDate'] = eventDate.toIso8601String();
    if (startDate != null) body['startDate'] = startDate.toIso8601String();
    if (endDate != null) body['endDate'] = endDate.toIso8601String();
    if (playlistName != null) body['playlistName'] = playlistName;
    if (selectedPlaylistId != null)
      body['selectedPlaylistId'] = selectedPlaylistId;

    final response = await apiService.patch(
      '${AppConfig.eventsEndpoint}/$id',
      body: body,
    );

    // Handle both wrapped response (with 'data' field) and direct data response
    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception(
        'Invalid response format: expected Map but got ${response.runtimeType}',
      );
    }

    return Event.fromJson(eventData);
  }

  /// Delete event
  Future<void> deleteEvent(String id) async {
    await apiService.delete('${AppConfig.eventsEndpoint}/$id');
  }

  // ========== PLAYLIST METHODS (Wrappers around Event methods) ==========
  // Since Event IS a Playlist with type='playlist', these methods simply
  // delegate to the Event methods with the appropriate type parameter

  /// Get all playlists - delegates to getEvents with type filter
  Future<List<Event>> getPlaylists({int page = 1, int limit = 20}) async {
    final allEvents = await getEvents(page: page, limit: limit);
    return allEvents.where((e) => e.isPlaylist).toList();
  }

  /// Get my playlists - delegates to getMyEvents with type filter
  Future<List<Event>> getMyPlaylists({int page = 1, int limit = 20}) async {
    final myEvents = await getMyEvents(page: page, limit: limit);
    return myEvents.where((e) => e.isPlaylist).toList();
  }

  /// Get playlist by ID - delegates to getEvent
  Future<Event> getPlaylist(String playlistId) async {
    return getEvent(playlistId);
  }

  /// Create playlist - delegates to createEvent with type='playlist'
  Future<Event> createPlaylist({
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

  /// Update playlist - delegates to updateEvent
  Future<Event> updatePlaylist(
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
      visibility: isPublic != null ? (isPublic ? 'public' : 'private') : null,
      licenseType: eventLicenseType,
      type: 'playlist',
    );
  }

  /// Delete playlist - delegates to deleteEvent
  Future<void> deletePlaylist(String id) async {
    return deleteEvent(id);
  }

  /// Get recommended playlists
  Future<List<Event>> getRecommendedPlaylists({int limit = 20}) async {
    final endpoint =
        '${AppConfig.eventsEndpoint}/recommended?limit=$limit&type=playlist';
    final response = await apiService.get(endpoint);

    if (response is List) {
      return response
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Search playlists
  Future<List<Event>> searchPlaylists(String query, {int limit = 20}) async {
    final endpoint =
        '${AppConfig.eventsEndpoint}/search?q=$query&limit=$limit&type=playlist';
    final response = await apiService.get(endpoint);

    if (response is List) {
      return response
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get playlist tracks
  Future<List<PlaylistTrack>> getPlaylistTracks(String playlistId) async {
    final response = await apiService.get(
      '${AppConfig.eventsEndpoint}/$playlistId',
    );

    List<dynamic> dataList;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      dataList = response['data'] as List;
    } else if (response is List) {
      dataList = response;
    } else {
      throw Exception('Invalid response format');
    }

    return dataList
        .map((e) => PlaylistTrack.fromJson(e as Map<String, dynamic>))
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
      '/playlists/$playlistId/tracks',
      body: {
        'deezerId': deezerId,
        'title': title,
        'artist': artist,
        'album': album,
        'albumCoverUrl': albumCoverUrl,
        'previewUrl': previewUrl,
        'duration': duration,
      },
    );

    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }

    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Get track by id
  Future<PlaylistTrack> getTrackById(String trackId) async {
    final response = await apiService.get('/music/track/$trackId');
    
    Map<String, dynamic> trackData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      trackData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      trackData = response;
    } else {
      throw Exception('Invalid response format');
    }
    
    return PlaylistTrack.fromJson(trackData);
  }

  /// Remove track from playlist
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    await apiService.delete(
      '${AppConfig.eventsEndpoint}/$playlistId/tracks/$trackId',
    );
  }

  /// Invite users to an event (creates invitations for private events)
  /// This is the correct method for inviting friends to events
  Future<Map<String, dynamic>> inviteUsers(
    String eventId,
    List<String> userIds, {
    String? message,
  }) async {
    final response = await apiService.post(
      '${AppConfig.eventsEndpoint}/$eventId/invite',
      body: {'userIds': userIds, if (message != null) 'message': message},
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Add participant to event (allows owner/collaborator to invite friends)
  Future<Event> addParticipant(String eventId, String userId) async {
    final response = await apiService.post(
      '${AppConfig.eventsEndpoint}/$eventId/participant/$userId',
      body: {},
    );

    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception('Invalid response format');
    }

    return Event.fromJson(eventData);
  }

  /// Remove participant from event
  Future<Event> removeParticipant(String eventId, String userId) async {
    final response = await apiService.delete(
      '${AppConfig.eventsEndpoint}/$eventId/participant/$userId',
    );

    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception('Invalid response format');
    }

    return Event.fromJson(eventData);
  }
}
