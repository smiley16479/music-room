// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Invitation _$InvitationFromJson(Map<String, dynamic> json) => Invitation(
  id: json['id'] as String,
  playlistId: json['playlistId'] as String?,
  eventId: json['eventId'] as String?,
  senderId: json['inviterId'] as String,
  recipientId: json['inviteeId'] as String,
  message: json['message'] as String?,
  status: json['status'] as String,
  type: json['type'] as String,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  inviter: json['inviter'] == null
      ? null
      : User.fromJson(json['inviter'] as Map<String, dynamic>),
  invitee: json['invitee'] == null
      ? null
      : User.fromJson(json['invitee'] as Map<String, dynamic>),
);

Map<String, dynamic> _$InvitationToJson(Invitation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'playlistId': instance.playlistId,
      'eventId': instance.eventId,
      'inviterId': instance.senderId,
      'inviteeId': instance.recipientId,
      'message': instance.message,
      'status': instance.status,
      'type': instance.type,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'inviter': instance.inviter,
      'invitee': instance.invitee,
    };
