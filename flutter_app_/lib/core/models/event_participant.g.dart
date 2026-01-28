// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_participant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventParticipant _$EventParticipantFromJson(Map<String, dynamic> json) =>
    EventParticipant(
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      role: $enumDecode(_$ParticipantRoleEnumMap, json['role']),
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.parse(json['joined_at'] as String),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$EventParticipantToJson(EventParticipant instance) =>
    <String, dynamic>{
      'event_id': instance.eventId,
      'user_id': instance.userId,
      'role': _$ParticipantRoleEnumMap[instance.role]!,
      'joined_at': instance.joinedAt?.toIso8601String(),
      'user': instance.user,
    };

const _$ParticipantRoleEnumMap = {
  ParticipantRole.admin: 'admin',
  ParticipantRole.creator: 'creator',
  ParticipantRole.collaborator: 'collaborator',
  ParticipantRole.participant: 'participant',
};
