import 'package:flutter/foundation.dart' show debugPrint;
import '../../config/app_config.dart';
import '../models/index.dart';
import 'api_service.dart';

/// Voting Service - manages voting operations for events
class VotingService {
  final ApiService apiService;

  VotingService({required this.apiService});

  /// Get voting results for an event
  Future<VotingResults> getVotingResults(String eventId) async {
    final endpoint = '${AppConfig.eventsEndpoint}/$eventId/voting-results';
    final response = await apiService.get(endpoint);

    debugPrint('Voting results response: $response');

    // Handle wrapped response
    Map<String, dynamic> data;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      data = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      data = response;
    } else {
      throw Exception('Invalid response format for voting results');
    }

    return VotingResults.fromJson(data);
  }

  /// Submit a vote for a track (upvote or downvote)
  /// If user already has the same vote type, it will be removed (toggle)
  /// If user has a different vote type, it will be changed
  /// Optional latitude and longitude for location-based events
  Future<void> vote({
    required String eventId,
    required String trackId,
    required VoteType type,
    double? latitude,
    double? longitude,
  }) async {
    final endpoint = '${AppConfig.eventsEndpoint}/$eventId/vote';
    
    final Map<String, dynamic> body = {
      'trackId': trackId,
      'type': type == VoteType.upvote ? 'upvote' : 'downvote',
    };
    
    // Add location if provided
    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
    }
    
    await apiService.post(endpoint, body: body);

    debugPrint('Vote submitted: $type for track $trackId in event $eventId');
  }

  /// Upvote a track
  Future<void> upvote(String eventId, String trackId, {double? latitude, double? longitude}) async {
    await vote(
      eventId: eventId,
      trackId: trackId,
      type: VoteType.upvote,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Downvote a track
  Future<void> downvote(String eventId, String trackId, {double? latitude, double? longitude}) async {
    await vote(
      eventId: eventId,
      trackId: trackId,
      type: VoteType.downvote,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Remove vote for a track
  Future<void> removeVote(String eventId, String trackId) async {
    final endpoint = '${AppConfig.eventsEndpoint}/$eventId/vote/$trackId';
    await apiService.delete(endpoint);
    debugPrint('Vote removed for track $trackId in event $eventId');
  }

  /// Get user's vote for a specific track
  TrackVoteInfo? getUserVoteForTrack(VotingResults results, String trackId) {
    return results.getTrackVoteInfo(trackId);
  }

  /// Check if user has voted for a track
  bool hasUserVoted(VotingResults results, String trackId) {
    final trackInfo = results.getTrackVoteInfo(trackId);
    return trackInfo?.userVote != null;
  }

  /// Get user's vote type for a track (null if not voted)
  VoteType? getUserVoteType(VotingResults results, String trackId) {
    final trackInfo = results.getTrackVoteInfo(trackId);
    return trackInfo?.userVote?.type;
  }
}
