import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Voting Provider - manages voting state for event playlists
class VotingProvider extends ChangeNotifier {
  final VotingService votingService;
  final WebSocketService webSocketService;

  // Current event ID for voting
  String? _currentEventId;

  // Voting results cache
  Map<String, TrackVoteInfo> _trackVotes = {};

  // Loading and error state
  bool _isLoading = false;
  String? _error;

  VotingProvider({
    required this.votingService,
    required this.webSocketService,
  }) {
    _setupWebSocketListeners();
  }

  // Getters
  String? get currentEventId => _currentEventId;
  Map<String, TrackVoteInfo> get trackVotes => _trackVotes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get vote info for a specific track
  TrackVoteInfo? getTrackVoteInfo(String trackId) {
    return _trackVotes[trackId];
  }

  /// Get user's vote for a specific track
  VoteType? getUserVote(String trackId) {
    return _trackVotes[trackId]?.userVote?.type;
  }

  /// Setup WebSocket listeners for real-time vote updates
  void _setupWebSocketListeners() {
    // Listen for voting results updates
    webSocketService.on('voting-results', (data) {
      debugPrint('📊 Received voting-results: $data');
      if (data is Map<String, dynamic>) {
        _handleVotingResults(data);
      }
    });

    // Listen for individual vote updates (when someone votes)
    webSocketService.on('vote-updated', (data) {
      debugPrint('🗳️ ✅ Vote updated: $data');
      if (data is Map<String, dynamic>) {
        _handleVoteUpdated(data);
      }
    });

    // Listen for vote removals (when someone removes their vote)
    webSocketService.on('vote-removed', (data) {
      debugPrint('🗳️ ❌ Vote removed: $data');
      if (data is Map<String, dynamic>) {
        _handleVoteRemoved(data);
      }
    });

    // Listen for queue reordered (votes changed order)
    webSocketService.on('queue-reordered', (data) {
      debugPrint('🔄 Queue reordered: $data');
      if (data is Map<String, dynamic>) {
        _handleQueueReordered(data);
      }
    });

    // Listen for individual track vote changes
    webSocketService.on('track-votes-changed', (data) {
      debugPrint('👍 Track votes changed: $data');
      if (data is Map<String, dynamic>) {
        _handleTrackVoteChanged(data);
      }
    });
  }

  /// Handle voting results from WebSocket
  void _handleVotingResults(Map<String, dynamic> data) {
    try {
      final tracks = data['tracks'] as List<dynamic>?;
      if (tracks != null) {
        _trackVotes.clear();
        for (final track in tracks) {
          final trackInfo = TrackVoteInfo.fromJson(
            track as Map<String, dynamic>,
          );
          _trackVotes[trackInfo.trackId] = trackInfo;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error handling voting results: $e');
    }
  }

  /// Handle individual track vote change
  void _handleTrackVoteChanged(Map<String, dynamic> data) {
    try {
      final eventId = data['eventId'] as String?;
      if (eventId != _currentEventId) return;

      final trackId = data['trackId'] as String?;
      final upvotes = data['upvotes'] as int? ?? 0;
      final downvotes = data['downvotes'] as int? ?? 0;
      final score = data['score'] as int? ?? 0;

      if (trackId != null) {
        final existing = _trackVotes[trackId];
        _trackVotes[trackId] = TrackVoteInfo(
          trackId: trackId,
          playlistTrackId: existing?.playlistTrackId,
          upvotes: upvotes,
          downvotes: downvotes,
          score: score,
          position: existing?.position ?? 0,
          userVote: existing?.userVote, // Keep existing user vote until updated
        );
        notifyListeners();
        debugPrint(
          '✅ Track $trackId votes updated: up=$upvotes, down=$downvotes, score=$score',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling track vote change: $e');
    }
  }

  /// Handle vote updated event from WebSocket
  void _handleVoteUpdated(Map<String, dynamic> data) {
    try {
      final eventId = data['eventId'] as String?;
      if (eventId != _currentEventId) return;

      final voteData = data['vote'] as Map<String, dynamic>?;
      if (voteData == null) return;

      final trackId = voteData['trackId'] as String?;
      if (trackId == null) return;

      // Instead of full reload, just fetch updated voting results
      // This is lighter than reloading the entire playlist
      loadVotingResults();
    } catch (e) {
      debugPrint('❌ Error handling vote updated: $e');
    }
  }

  /// Handle vote removed event from WebSocket
  void _handleVoteRemoved(Map<String, dynamic> data) {
    try {
      final eventId = data['eventId'] as String?;
      if (eventId != _currentEventId) return;

      final voteData = data['vote'] as Map<String, dynamic>?;
      if (voteData == null) return;

      final trackId = voteData['trackId'] as String?;
      if (trackId == null) return;

      // Instead of full reload, just fetch updated voting results
      // This is lighter than reloading the entire playlist
      loadVotingResults();
    } catch (e) {
      debugPrint('❌ Error handling vote removed: $e');
    }
  }

  /// Handle queue reordered event from WebSocket
  /// This is called when votes have changed the track order
  void _handleQueueReordered(Map<String, dynamic> data) {
    try {
      final eventId = data['eventId'] as String?;
      if (eventId != _currentEventId) return;

      // trackScores contains the updated vote scores for each track
      final trackScores = data['trackScores'] as Map<String, dynamic>?;

      if (trackScores != null) {
        // Update scores for all tracks based on the new data
        for (final entry in trackScores.entries) {
          final trackId = entry.key;
          final score = (entry.value as num).toInt();

          final existing = _trackVotes[trackId];
          if (existing != null) {
            // Update the score (we don't have individual up/down counts here)
            // Calculate approximate up/down based on score
            final upvotes = score > 0 ? score : 0;
            final downvotes = score < 0 ? -score : 0;

            _trackVotes[trackId] = TrackVoteInfo(
              trackId: trackId,
              playlistTrackId: existing.playlistTrackId,
              upvotes: upvotes,
              downvotes: downvotes,
              score: score,
              position: existing.position,
              userVote: existing.userVote,
            );
          } else {
            // New track we didn't know about
            final upvotes = score > 0 ? score : 0;
            final downvotes = score < 0 ? -score : 0;

            _trackVotes[trackId] = TrackVoteInfo(
              trackId: trackId,
              playlistTrackId: null,
              upvotes: upvotes,
              downvotes: downvotes,
              score: score,
              position: 0,
              userVote: null,
            );
          }
        }
      }

      notifyListeners();
      debugPrint(
        '✅ Queue reordered handled, updated ${trackScores?.length ?? 0} track scores',
      );
    } catch (e) {
      debugPrint('❌ Error handling queue reordered: $e');
    }
  }

  /// Set current event for voting
  Future<void> setCurrentEvent(String eventId) async {
    if (_currentEventId == eventId) return;

    _currentEventId = eventId;
    _trackVotes.clear();
    await loadVotingResults();
  }

  /// Load voting results for current event
  Future<void> loadVotingResults() async {
    if (_currentEventId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await votingService.getVotingResults(_currentEventId!);
      _trackVotes.clear();
      for (final trackInfo in results.tracks) {
        _trackVotes[trackInfo.trackId] = trackInfo;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading voting results: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Upvote a track
  Future<bool> upvoteTrack(String trackId) async {
    if (_currentEventId == null) return false;

    try {
      // Check if user already has an upvote - if so, this is a toggle (remove)
      final currentVote = getUserVote(trackId);
      final isToggleOff = currentVote == VoteType.upvote;

      // Optimistic update for immediate UI feedback
      _updateLocalVote(trackId, isToggleOff ? null : VoteType.upvote);

      // Call API for persistence - WebSocket events will handle the real-time sync
      // Note: We don't also send via WebSocket to avoid duplicate vote processing
      await votingService.upvote(_currentEventId!, trackId);

      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error upvoting track: $e');
      // Revert optimistic update on error
      await loadVotingResults();
      return false;
    }
  }

  /// Downvote a track
  Future<bool> downvoteTrack(String trackId) async {
    if (_currentEventId == null) return false;

    try {
      // Check if user already has a downvote - if so, this is a toggle (remove)
      final currentVote = getUserVote(trackId);
      final isToggleOff = currentVote == VoteType.downvote;

      // Optimistic update for immediate UI feedback
      _updateLocalVote(trackId, isToggleOff ? null : VoteType.downvote);

      // Call API for persistence - WebSocket events will handle the real-time sync
      await votingService.downvote(_currentEventId!, trackId);

      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error downvoting track: $e');
      // Revert optimistic update on error
      await loadVotingResults();
      return false;
    }
  }

  /// Remove vote from a track
  Future<bool> removeVote(String trackId) async {
    if (_currentEventId == null) return false;

    try {
      // Optimistic update for immediate UI feedback
      _updateLocalVote(trackId, null);

      // Call API for persistence - WebSocket events will handle the real-time sync
      await votingService.removeVote(_currentEventId!, trackId);

      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error removing vote: $e');
      // Revert optimistic update on error
      await loadVotingResults();
      return false;
    }
  }

  /// Vote for a track (unified method)
  Future<bool> vote(String trackId, VoteType voteType) async {
    if (voteType == VoteType.upvote) {
      return upvoteTrack(trackId);
    } else {
      return downvoteTrack(trackId);
    }
  }

  /// Update local vote optimistically
  void _updateLocalVote(String trackId, VoteType? newVote) {
    final existing = _trackVotes[trackId];
    final newUserVote = newVote != null ? UserVoteInfo(type: newVote) : null;

    if (existing == null) {
      _trackVotes[trackId] = TrackVoteInfo(
        trackId: trackId,
        playlistTrackId: null,
        upvotes: newVote == VoteType.upvote ? 1 : 0,
        downvotes: newVote == VoteType.downvote ? 1 : 0,
        score: newVote == VoteType.upvote
            ? 1
            : (newVote == VoteType.downvote ? -1 : 0),
        position: 0,
        userVote: newUserVote,
      );
    } else {
      // Calculate vote change
      int upvoteChange = 0;
      int downvoteChange = 0;

      // Remove previous vote
      if (existing.userVote?.type == VoteType.upvote) {
        upvoteChange -= 1;
      } else if (existing.userVote?.type == VoteType.downvote) {
        downvoteChange -= 1;
      }

      // Add new vote
      if (newVote == VoteType.upvote) {
        upvoteChange += 1;
      } else if (newVote == VoteType.downvote) {
        downvoteChange += 1;
      }

      _trackVotes[trackId] = TrackVoteInfo(
        trackId: trackId,
        playlistTrackId: existing.playlistTrackId,
        upvotes: existing.upvotes + upvoteChange,
        downvotes: existing.downvotes + downvoteChange,
        score:
            (existing.upvotes + upvoteChange) -
            (existing.downvotes + downvoteChange),
        position: existing.position,
        userVote: newUserVote,
      );
    }
    notifyListeners();
  }

  /// Clear voting state (when leaving event)
  void clearVotingState() {
    _currentEventId = null;
    _trackVotes.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Remove WebSocket listeners
    webSocketService.off('voting-results');
    webSocketService.off('vote-updated');
    webSocketService.off('vote-removed');
    webSocketService.off('queue-reordered');
    webSocketService.off('track-votes-changed');
    super.dispose();
  }
}
