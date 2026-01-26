import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'playlist_track.g.dart';

/// PlaylistTrack model - represents a track in an event/playlist
/// Note: playlistId now points to Event (Event IS Playlist when type=LISTENING_SESSION)
@JsonSerializable()
class PlaylistTrack extends Equatable {
  final String id;
  @JsonKey(name: 'eventId') // Backend uses eventId now
  final String playlistId; // Kept for compatibility
  final String trackId;
  final int position;
  final int votes;
  final String? trackTitle;
  final String? trackArtist;
  final String? trackAlbum;
  final String? coverUrl;
  final int? duration;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlaylistTrack({
    required this.id,
    required this.playlistId, // Actually eventId from backend
    required this.trackId,
    required this.position,
    required this.votes,
    this.trackTitle,
    this.trackArtist,
    this.trackAlbum,
    this.coverUrl,
    this.duration,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) =>
      _$PlaylistTrackFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistTrackToJson(this);

  @override
  List<Object?> get props => [
        id,
        playlistId,
        trackId,
        position,
        votes,
        trackTitle,
        trackArtist,
        trackAlbum,
        coverUrl,
        duration,
        createdAt,
        updatedAt,
      ];
}
