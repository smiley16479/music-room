// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_participant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventParticipant _$EventParticipantFromJson(Map<String, dynamic> json) =>
    EventParticipant(
      eventId: json['eventId'] as String,
      userId: json['userId'] as String,
      role: $enumDecode(_$ParticipantRoleEnumMap, json['role']),
      joinedAt: json['joinedAt'] == null
          ? null
          : DateTime.parse(json['joinedAt'] as String),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$EventParticipantToJson(EventParticipant instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'userId': instance.userId,
      'role': _$ParticipantRoleEnumMap[instance.role]!,
      'joinedAt': instance.joinedAt?.toIso8601String(),
      'user': instance.user,
    };

const _$ParticipantRoleEnumMap = {
  ParticipantRole.admin: 'admin',
  ParticipantRole.creator: 'creator',
  ParticipantRole.collaborator: 'collaborator',
  ParticipantRole.participant: 'participant',
};
