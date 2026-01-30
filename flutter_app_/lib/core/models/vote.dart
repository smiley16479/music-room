import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vote.g.dart';

/// Vote Type enum
enum VoteType {
  @JsonValue('upvote')
  upvote,
  @JsonValue('downvote')
  downvote,
}

/// Vote model - represents a user's vote on a track
@JsonSerializable()
class Vote extends Equatable {
  final String id;
  final String eventId;
  final String userId;
  final String trackId;
  final String? playlistTrackId;
  final VoteType type;
  final int weight;
  final DateTime createdAt;

  const Vote({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.trackId,
    this.playlistTrackId,
    required this.type,
    this.weight = 1,
    required this.createdAt,
  });

  factory Vote.fromJson(Map<String, dynamic> json) => _$VoteFromJson(json);
  Map<String, dynamic> toJson() => _$VoteToJson(this);

  @override
  List<Object?> get props => [
        id,
        eventId,
        userId,
        trackId,
        playlistTrackId,
        type,
        weight,
        createdAt,
      ];
}

/// Track vote info - aggregated vote data for a track
@JsonSerializable()
class TrackVoteInfo extends Equatable {
  final String trackId;
  final String? playlistTrackId;
  final int upvotes;
  final int downvotes;
  final int score;
  final int position;
  final bool isCurrentTrack;
  @JsonKey(name: 'userVote')
  final UserVoteInfo? userVote;

  const TrackVoteInfo({
    required this.trackId,
    this.playlistTrackId,
    required this.upvotes,
    required this.downvotes,
    required this.score,
    required this.position,
    this.isCurrentTrack = false,
    this.userVote,
  });

  factory TrackVoteInfo.fromJson(Map<String, dynamic> json) =>
      _$TrackVoteInfoFromJson(json);
  Map<String, dynamic> toJson() => _$TrackVoteInfoToJson(this);

  @override
  List<Object?> get props => [
        trackId,
        playlistTrackId,
        upvotes,
        downvotes,
        score,
        position,
        isCurrentTrack,
        userVote,
      ];
}

/// User vote info - the current user's vote on a track
@JsonSerializable()
class UserVoteInfo extends Equatable {
  final VoteType type;
  final int weight;

  const UserVoteInfo({
    required this.type,
    this.weight = 1,
  });

  factory UserVoteInfo.fromJson(Map<String, dynamic> json) =>
      _$UserVoteInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UserVoteInfoToJson(this);

  @override
  List<Object?> get props => [type, weight];
}

/// Voting results response from API
@JsonSerializable()
class VotingResults extends Equatable {
  final String eventId;
  final String? currentTrackId;
  final List<TrackVoteInfo> tracks;
  final int totalVotes;

  const VotingResults({
    required this.eventId,
    this.currentTrackId,
    required this.tracks,
    required this.totalVotes,
  });

  factory VotingResults.fromJson(Map<String, dynamic> json) =>
      _$VotingResultsFromJson(json);
  Map<String, dynamic> toJson() => _$VotingResultsToJson(this);

  /// Get track vote info by track ID
  TrackVoteInfo? getTrackVoteInfo(String trackId) {
    try {
      return tracks.firstWhere((t) => t.trackId == trackId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [eventId, currentTrackId, tracks, totalVotes];
}
