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

    // Listen for queue reordered (votes changed order)
    webSocketService.on('queue-reordered', (data) {
      debugPrint('🔄 Queue reordered: $data');
      // Notify listeners so UI can refresh
      notifyListeners();
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
          final trackInfo = TrackVoteInfo.fromJson(track as Map<String, dynamic>);
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
      }
    } catch (e) {
      debugPrint('❌ Error handling track vote change: $e');
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
      // Optimistic update
      _updateLocalVote(trackId, VoteType.upvote);

      // Send via WebSocket for real-time sync
      webSocketService.upvoteTrack(_currentEventId!, trackId);

      // Also call API for persistence
      await votingService.upvote(_currentEventId!, trackId);
      
      // Reload to get updated vote counts
      await loadVotingResults();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error upvoting track: $e');
      // Revert optimistic update
      await loadVotingResults();
      return false;
    }
  }

  /// Downvote a track
  Future<bool> downvoteTrack(String trackId) async {
    if (_currentEventId == null) return false;

    try {
      // Optimistic update
      _updateLocalVote(trackId, VoteType.downvote);

      // Send via WebSocket for real-time sync
      webSocketService.downvoteTrack(_currentEventId!, trackId);

      // Also call API for persistence
      await votingService.downvote(_currentEventId!, trackId);
      
      // Reload to get updated vote counts
      await loadVotingResults();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error downvoting track: $e');
      // Revert optimistic update
      await loadVotingResults();
      return false;
    }
  }

  /// Remove vote from a track
  Future<bool> removeVote(String trackId) async {
    if (_currentEventId == null) return false;

    try {
      // Optimistic update
      _updateLocalVote(trackId, null);

      // Send via WebSocket for real-time sync
      webSocketService.removeVote(_currentEventId!, trackId);

      // Also call API for persistence
      await votingService.removeVote(_currentEventId!, trackId);
      
      // Reload to get updated vote counts
      await loadVotingResults();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error removing vote: $e');
      // Revert optimistic update
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
        score: newVote == VoteType.upvote ? 1 : (newVote == VoteType.downvote ? -1 : 0),
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
        score: (existing.upvotes + upvoteChange) - (existing.downvotes + downvoteChange),
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
    webSocketService.off('queue-reordered');
    webSocketService.off('track-votes-changed');
    super.dispose();
  }
}
