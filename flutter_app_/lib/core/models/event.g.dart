// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  eventDate: json['eventDate'] == null
      ? null
      : DateTime.parse(json['eventDate'] as String),
  eventEndDate: json['eventEndDate'] == null
      ? null
      : DateTime.parse(json['eventEndDate'] as String),
  creatorId: json['creatorId'] as String?,
  creator: json['creator'] == null
      ? null
      : User.fromJson(json['creator'] as Map<String, dynamic>),
  locationName: json['locationName'] as String?,
  visibility: json['visibility'] as String,
  licenseType: json['licenseType'] as String?,
  status: json['status'] as String,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  locationRadius: (json['locationRadius'] as num?)?.toInt(),
  votingStartTime: json['votingStartTime'] as String?,
  votingEndTime: json['votingEndTime'] as String?,
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
  'eventDate': instance.eventDate?.toIso8601String(),
  'eventEndDate': instance.eventEndDate?.toIso8601String(),
  'creatorId': instance.creatorId,
  'creator': instance.creator,
  'locationName': instance.locationName,
  'visibility': instance.visibility,
  'licenseType': instance.licenseType,
  'status': instance.status,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'locationRadius': instance.locationRadius,
  'votingStartTime': instance.votingStartTime,
  'votingEndTime': instance.votingEndTime,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'participants': instance.participants,
  'participantsCount': instance.participantsCount,
  'votes': instance.votes,
};
