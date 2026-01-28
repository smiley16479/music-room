import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';
import 'event_participant.dart';

part 'event.g.dart';

/// Event Type enum
enum EventType {
  @JsonValue('playlist')
  playlist, // = Playlist
  @JsonValue('event')
  event,
}

/// Event Visibility enum
enum EventVisibility {
  @JsonValue('public')
  public,
  @JsonValue('private')
  private,
}

/// Event License Type enum
enum EventLicenseType {
  @JsonValue('none')
  none,
  @JsonValue('invited')
  invited,
  @JsonValue('location_based')
  locationBased,
}

/// Event model (unifié avec Playlist)
@JsonSerializable()
class Event extends Equatable {
  final String id;
  final String name;
  final String? description;

  // Event type
  final EventType type;
  final EventVisibility visibility;
  final EventLicenseType? licenseType;

  // Playlist-specific fields
  final int? trackCount;
  final int? totalDuration;
  final int? collaboratorCount;
  final String? coverImageUrl;
  final String? playlistName;

  // Event-specific fields
  @JsonKey(name: 'eventDate')
  final DateTime? eventDate;
  @JsonKey(name: 'eventEndDate')
  final DateTime? eventEndDate;
  @JsonKey(name: 'startDate')
  final DateTime? startDate;
  @JsonKey(name: 'endDate')
  final DateTime? endDate;
  @JsonKey(name: 'locationName')
  final String? locationName;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'locationRadius')
  final int? locationRadius;

  // Voting
  @JsonKey(name: 'votingEnabled')
  final bool? votingEnabled;
  @JsonKey(name: 'votingStartTime')
  final String? votingStartTime;
  @JsonKey(name: 'votingEndTime')
  final String? votingEndTime;
  @JsonKey(name: 'currentTrackId')
  final String? currentTrackId;

  // Common fields
  @JsonKey(name: 'creatorId')
  final String? creatorId;
  @JsonKey(name: 'creator')
  final User? creator;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final List<EventParticipant>? participants;
  @JsonKey(name: 'participantsCount', fromJson: _participantsCountFromJson)
  final int? participantsCount;
  @JsonKey(name: 'votes', fromJson: _votesFromJson)
  final int? votes;

  const Event({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.visibility,
    this.licenseType,
    this.trackCount,
    this.totalDuration,
    this.collaboratorCount,
    this.coverImageUrl,
    this.playlistName,
    this.eventDate,
    this.eventEndDate,
    this.startDate,
    this.endDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.locationRadius,
    this.votingEnabled,
    this.votingStartTime,
    this.votingEndTime,
    this.currentTrackId,
    this.creatorId,
    this.creator,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.participants,
    this.participantsCount,
    this.votes,
  });

  /// Helper: Est-ce une playlist ?
  bool get isPlaylist => type == EventType.playlist;

  /// Helper: Nombre de pistes (alias pour UI)
  int get numberOfTracks => trackCount ?? 0;

  /// Helper: Is this event created by the current user? ⚠️ assure toi que ça marche
  /// Returns true if creatorId is not null (assumption: we're checking against current user in provider)
  bool get isCreatedByMe => creatorId != null;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    type,
    visibility,
    licenseType,
    trackCount,
    totalDuration,
    collaboratorCount,
    coverImageUrl,
    playlistName,
    eventDate,
    eventEndDate,
    startDate,
    endDate,
    creatorId,
    creator,
    locationName,
    latitude,
    longitude,
    locationRadius,
    votingEnabled,
    votingStartTime,
    votingEndTime,
    currentTrackId,
    status,
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
