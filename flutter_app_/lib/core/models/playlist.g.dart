// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Playlist _$PlaylistFromJson(Map<String, dynamic> json) => Playlist(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  ownerId: json['ownerId'] as String,
  owner: json['owner'] == null
      ? null
      : User.fromJson(json['owner'] as Map<String, dynamic>),
  isPublic: json['isPublic'] as bool,
  trackCount: (json['trackCount'] as num).toInt(),
  collaboratorCount: (json['collaboratorCount'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PlaylistToJson(Playlist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'ownerId': instance.ownerId,
  'owner': instance.owner,
  'isPublic': instance.isPublic,
  'trackCount': instance.trackCount,
  'collaboratorCount': instance.collaboratorCount,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
