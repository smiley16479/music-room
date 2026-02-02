// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Vote _$VoteFromJson(Map<String, dynamic> json) => Vote(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      userId: json['userId'] as String,
      trackId: json['trackId'] as String,
      playlistTrackId: json['playlistTrackId'] as String?,
      type: $enumDecode(_$VoteTypeEnumMap, json['type']),
      weight: (json['weight'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$VoteToJson(Vote instance) => <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'userId': instance.userId,
      'trackId': instance.trackId,
      'playlistTrackId': instance.playlistTrackId,
      'type': _$VoteTypeEnumMap[instance.type]!,
      'weight': instance.weight,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$VoteTypeEnumMap = {
  VoteType.upvote: 'upvote',
  VoteType.downvote: 'downvote',
};

TrackVoteInfo _$TrackVoteInfoFromJson(Map<String, dynamic> json) =>
    TrackVoteInfo(
      trackId: json['trackId'] as String,
      playlistTrackId: json['playlistTrackId'] as String?,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isCurrentTrack: json['isCurrentTrack'] as bool? ?? false,
      userVote: json['userVote'] == null
          ? null
          : UserVoteInfo.fromJson(json['userVote'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TrackVoteInfoToJson(TrackVoteInfo instance) =>
    <String, dynamic>{
      'trackId': instance.trackId,
      'playlistTrackId': instance.playlistTrackId,
      'upvotes': instance.upvotes,
      'downvotes': instance.downvotes,
      'score': instance.score,
      'position': instance.position,
      'isCurrentTrack': instance.isCurrentTrack,
      'userVote': instance.userVote?.toJson(),
    };

UserVoteInfo _$UserVoteInfoFromJson(Map<String, dynamic> json) => UserVoteInfo(
      type: $enumDecode(_$VoteTypeEnumMap, json['type']),
      weight: (json['weight'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$UserVoteInfoToJson(UserVoteInfo instance) =>
    <String, dynamic>{
      'type': _$VoteTypeEnumMap[instance.type]!,
      'weight': instance.weight,
    };

VotingResults _$VotingResultsFromJson(Map<String, dynamic> json) =>
    VotingResults(
      eventId: json['eventId'] as String,
      currentTrackId: json['currentTrackId'] as String?,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((e) => TrackVoteInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$VotingResultsToJson(VotingResults instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'currentTrackId': instance.currentTrackId,
      'tracks': instance.tracks.map((e) => e.toJson()).toList(),
      'totalVotes': instance.totalVotes,
    };
