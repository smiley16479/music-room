import 'package:equatable/equatable.dart';

/// Track search result model
class TrackSearchResult extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? albumCoverUrl;
  final String? previewUrl;
  final int? duration;
  final String source; // 'spotify' or 'deezer'

  const TrackSearchResult({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumCoverUrl,
    this.previewUrl,
    this.duration,
    required this.source,
  });

  factory TrackSearchResult.fromSpotifyJson(Map<String, dynamic> json) {
    return TrackSearchResult(
      id: json['id'] as String,
      title: json['name'] as String,
      artist: (json['artists'] as List).map((a) => a['name']).join(', '),
      album: json['album']?['name'] as String?,
      albumCoverUrl: (json['album']?['images'] as List?)?.isNotEmpty == true
          ? json['album']['images'][0]['url'] as String?
          : null,
      previewUrl: json['preview_url'] as String?,
      duration: json['duration_ms'] != null 
          ? (json['duration_ms'] as int) ~/ 1000 
          : null,
      source: 'spotify',
    );
  }

  factory TrackSearchResult.fromDeezerJson(Map<String, dynamic> json) {
    return TrackSearchResult(
      id: json['id'].toString(),
      title: json['title'] as String,
      artist: json['artist']?['name'] as String? ?? 'Unknown',
      album: json['album']?['title'] as String?,
      albumCoverUrl: json['album']?['cover_medium'] as String?,
      previewUrl: json['preview'] as String?,
      duration: json['duration'] as int?,
      source: 'deezer',
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        album,
        albumCoverUrl,
        previewUrl,
        duration,
        source,
      ];
}
