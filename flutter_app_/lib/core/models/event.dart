import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'event.g.dart';

/// Event Type enum
enum EventType {
  @JsonValue('LISTENING_SESSION')
  listeningSession, // = Playlist
  @JsonValue('PARTY')
  party,
  @JsonValue('COLLABORATIVE')
  collaborative,
  @JsonValue('LIVE_SESSION')
  liveSession,
}

/// Event Visibility enum  
enum EventVisibility {
  @JsonValue('PUBLIC')
  public,
  @JsonValue('PRIVATE')
  private,
}

/// Event model (unifié avec Playlist)
/// Un Event de type LISTENING_SESSION EST une playlist
@JsonSerializable()
class Event extends Equatable {
  final String id;
  final String name;
  final String? description;
  
  // Event type (LISTENING_SESSION = playlist)
  final EventType type;
  final EventVisibility visibility;
  
  // Playlist-specific fields (nullable, only for LISTENING_SESSION)
  final int? trackCount;
  final int? totalDuration;
  final int? collaboratorCount;
  final String? coverImageUrl;
  
  // Event-specific fields
  @JsonKey(name: 'eventDate')
  final DateTime? eventDate;
  @JsonKey(name: 'eventEndDate')
  final DateTime? eventEndDate;
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
  @JsonKey(name: 'licenseType')
  final String? licenseType;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Relations
  final List<User>? participants;
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
    this.trackCount,
    this.totalDuration,
    this.collaboratorCount,
    this.coverImageUrl,
    this.eventDate,
    this.eventEndDate,
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
    this.licenseType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.participants,
    this.participantsCount,
    this.votes,
  });
  
  /// Helper: Est-ce une playlist ?
  bool get isPlaylist => type == EventType.listeningSession;
  
  /// Helper: Nombre de pistes (alias pour UI)
  int get numberOfTracks => trackCount ?? 0;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        type,
        visibility,
        trackCount,
        totalDuration,
        collaboratorCount,
        coverImageUrl,
        eventDate,
        eventEndDate,
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
        licenseType,
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
