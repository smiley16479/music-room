import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'event.g.dart';

/// Event model
@JsonSerializable()
class Event extends Equatable {
  final String id;
  final String name;
  final String? description;
  @JsonKey(name: 'eventDate')
  final DateTime? eventDate;
  @JsonKey(name: 'eventEndDate')
  final DateTime? eventEndDate;
  @JsonKey(name: 'creatorId')
  final String? creatorId;
  @JsonKey(name: 'creator')
  final User? creator;
  @JsonKey(name: 'locationName')
  final String? locationName;
  final String visibility;
  @JsonKey(name: 'licenseType')
  final String? licenseType;
  final String status;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'locationRadius')
  final int? locationRadius;
  @JsonKey(name: 'votingStartTime')
  final String? votingStartTime;
  @JsonKey(name: 'votingEndTime')
  final String? votingEndTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<User>? participants;
  @JsonKey(name: 'participantsCount', fromJson: _participantsCountFromJson)
  final int? participantsCount;
  @JsonKey(name: 'votes', fromJson: _votesFromJson)
  final int? votes;

  const Event({
    required this.id,
    required this.name,
    this.description,
    this.eventDate,
    this.eventEndDate,
    this.creatorId,
    this.creator,
    this.locationName,
    required this.visibility,
    this.licenseType,
    required this.status,
    this.latitude,
    this.longitude,
    this.locationRadius,
    this.votingStartTime,
    this.votingEndTime,
    required this.createdAt,
    required this.updatedAt,
    this.participants,
    this.participantsCount,
    this.votes,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        eventDate,
        eventEndDate,
        creatorId,
        creator,
        locationName,
        visibility,
        licenseType,
        status,
        latitude,
        longitude,
        locationRadius,
        votingStartTime,
        votingEndTime,
        createdAt,
        updatedAt,
        participants,
        participantsCount,
        votes,
      ];
}

/// Convert votes from various formats to int
int? _votesFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is List) return value.length;
  if (value is String) return int.tryParse(value);
  return null;
}

/// Convert participantsCount from various formats to int
int? _participantsCountFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
