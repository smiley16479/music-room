import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'event_participant.g.dart';

enum ParticipantRole {
  @JsonValue('admin')
  admin,
  @JsonValue('creator')
  creator,
  @JsonValue('collaborator')
  collaborator,
  @JsonValue('participant')
  participant,
}

@JsonSerializable()
class EventParticipant {
  @JsonKey(name: 'event_id')
  final String eventId;
  
  @JsonKey(name: 'user_id')
  final String userId;
  
  final ParticipantRole role;
  
  @JsonKey(name: 'joined_at')
  final DateTime? joinedAt;
  
  final User? user;

  EventParticipant({
    required this.eventId,
    required this.userId,
    required this.role,
    this.joinedAt,
    this.user,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) =>
      _$EventParticipantFromJson(json);

  Map<String, dynamic> toJson() => _$EventParticipantToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventParticipant &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId &&
          userId == other.userId;

  @override
  int get hashCode => eventId.hashCode ^ userId.hashCode;
}
