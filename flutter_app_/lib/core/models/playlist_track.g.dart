// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaylistTrack _$PlaylistTrackFromJson(Map<String, dynamic> json) =>
    PlaylistTrack(
      id: json['id'] as String,
      playlistId: json['eventId'] as String,
      trackId: json['trackId'] as String,
      position: (json['position'] as num).toInt(),
      votes: (json['votes'] as num).toInt(),
      trackTitle: json['trackTitle'] as String?,
      trackArtist: json['trackArtist'] as String?,
      trackAlbum: json['trackAlbum'] as String?,
      coverUrl: json['coverUrl'] as String?,
      previewUrl: json['previewUrl'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$PlaylistTrackToJson(PlaylistTrack instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.playlistId,
      'trackId': instance.trackId,
      'position': instance.position,
      'votes': instance.votes,
      'trackTitle': instance.trackTitle,
      'trackArtist': instance.trackArtist,
      'trackAlbum': instance.trackAlbum,
      'coverUrl': instance.coverUrl,
      'previewUrl': instance.previewUrl,
      'duration': instance.duration,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
