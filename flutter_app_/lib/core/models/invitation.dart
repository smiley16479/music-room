import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'invitation.g.dart';

/// Invitation type enum
enum InvitationType { event, playlist, friend }

/// Invitation status enum
enum InvitationStatus { pending, accepted, declined, expired }

/// Invitation model - supports event, playlist, and friend invitations
@JsonSerializable()
class Invitation extends Equatable {
  final String id;
  final String? playlistId;
  final String? eventId;
  @JsonKey(name: 'inviterId')
  final String senderId;
  @JsonKey(name: 'inviteeId')
  final String recipientId;
  final String? message;
  final String status; // pending, accepted, declined, expired
  final String type; // event, playlist, friend
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Related user objects (populated when fetching invitations)
  final User? inviter;
  final User? invitee;

  const Invitation({
    required this.id,
    this.playlistId,
    this.eventId,
    required this.senderId,
    required this.recipientId,
    this.message,
    required this.status,
    required this.type,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.inviter,
    this.invitee,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isExpired => status == 'expired';
  
  bool get isFriendInvitation => type == 'friend';
  bool get isEventInvitation => type == 'event';
  bool get isPlaylistInvitation => type == 'playlist';

  factory Invitation.fromJson(Map<String, dynamic> json) =>
      _$InvitationFromJson(json);
  Map<String, dynamic> toJson() => _$InvitationToJson(this);

  @override
  List<Object?> get props => [
        id,
        playlistId,
        eventId,
        senderId,
        recipientId,
        message,
        status,
        type,
        expiresAt,
        createdAt,
        updatedAt,
        inviter,
        invitee,
      ];
}
