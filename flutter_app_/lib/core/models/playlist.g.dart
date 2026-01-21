// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Playlist _$PlaylistFromJson(Map<String, dynamic> json) => Playlist(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  ownerId: json['creatorId'] as String?,
  owner: json['creator'] == null
      ? null
      : User.fromJson(json['creator'] as Map<String, dynamic>),
  visibility: json['visibility'] as String?,
  trackCount: _trackCountFromJson(json['trackCount']),
  collaboratorCount: _collaboratorCountFromJson(json['collaboratorCount']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PlaylistToJson(Playlist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'creatorId': instance.ownerId,
  'creator': instance.owner,
  'visibility': instance.visibility,
  'trackCount': instance.trackCount,
  'collaboratorCount': instance.collaboratorCount,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
