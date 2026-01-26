// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  type: $enumDecode(_$EventTypeEnumMap, json['type']),
  visibility: $enumDecode(_$EventVisibilityEnumMap, json['visibility']),
  trackCount: (json['trackCount'] as num?)?.toInt(),
  totalDuration: (json['totalDuration'] as num?)?.toInt(),
  collaboratorCount: (json['collaboratorCount'] as num?)?.toInt(),
  coverImageUrl: json['coverImageUrl'] as String?,
  eventDate: json['eventDate'] == null
      ? null
      : DateTime.parse(json['eventDate'] as String),
  eventEndDate: json['eventEndDate'] == null
      ? null
      : DateTime.parse(json['eventEndDate'] as String),
  locationName: json['locationName'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  locationRadius: (json['locationRadius'] as num?)?.toInt(),
  votingEnabled: json['votingEnabled'] as bool?,
  votingStartTime: json['votingStartTime'] as String?,
  votingEndTime: json['votingEndTime'] as String?,
  currentTrackId: json['currentTrackId'] as String?,
  creatorId: json['creatorId'] as String?,
  creator: json['creator'] == null
      ? null
      : User.fromJson(json['creator'] as Map<String, dynamic>),
  licenseType: json['licenseType'] as String?,
  status: json['status'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  participants: (json['participants'] as List<dynamic>?)
      ?.map((e) => User.fromJson(e as Map<String, dynamic>))
      .toList(),
  participantsCount: _participantsCountFromJson(json['participantsCount']),
  votes: _votesFromJson(json['votes']),
);

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'type': _$EventTypeEnumMap[instance.type]!,
  'visibility': _$EventVisibilityEnumMap[instance.visibility]!,
  'trackCount': instance.trackCount,
  'totalDuration': instance.totalDuration,
  'collaboratorCount': instance.collaboratorCount,
  'coverImageUrl': instance.coverImageUrl,
  'eventDate': instance.eventDate?.toIso8601String(),
  'eventEndDate': instance.eventEndDate?.toIso8601String(),
  'locationName': instance.locationName,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'locationRadius': instance.locationRadius,
  'votingEnabled': instance.votingEnabled,
  'votingStartTime': instance.votingStartTime,
  'votingEndTime': instance.votingEndTime,
  'currentTrackId': instance.currentTrackId,
  'creatorId': instance.creatorId,
  'creator': instance.creator,
  'licenseType': instance.licenseType,
  'status': instance.status,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'participants': instance.participants,
  'participantsCount': instance.participantsCount,
  'votes': instance.votes,
};

const _$EventTypeEnumMap = {
  EventType.listeningSession: 'LISTENING_SESSION',
  EventType.party: 'PARTY',
  EventType.collaborative: 'COLLABORATIVE',
  EventType.liveSession: 'LIVE_SESSION',
};

const _$EventVisibilityEnumMap = {
  EventVisibility.public: 'PUBLIC',
  EventVisibility.private: 'PRIVATE',
};
