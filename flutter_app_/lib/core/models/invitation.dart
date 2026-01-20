import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'invitation.g.dart';

/// Invitation model
@JsonSerializable()
class Invitation extends Equatable {
  final String id;
  final String playlistId;
  final String senderId;
  final String recipientId;
  final String? message;
  final String status; // pending, accepted, declined
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invitation({
    required this.id,
    required this.playlistId,
    required this.senderId,
    required this.recipientId,
    this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  factory Invitation.fromJson(Map<String, dynamic> json) =>
      _$InvitationFromJson(json);
  Map<String, dynamic> toJson() => _$InvitationToJson(this);

  @override
  List<Object?> get props => [
        id,
        playlistId,
        senderId,
        recipientId,
        message,
        status,
        createdAt,
        updatedAt,
      ];
}
