import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'playlist_track.g.dart';

/// PlaylistTrack model - represents a track in a playlist with position and votes
@JsonSerializable()
class PlaylistTrack extends Equatable {
  final String id;
  final String playlistId;
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
    required this.playlistId,
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
