import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'track.g.dart';

/// Track model
@JsonSerializable()
class Track extends Equatable {
  final String id;
  final String deezerId;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String? coverUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Track({
    required this.id,
    required this.deezerId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.coverUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  String get durationString {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);

  @override
  List<Object?> get props => [
        id,
        deezerId,
        title,
        artist,
        album,
        duration,
        coverUrl,
        createdAt,
        updatedAt,
      ];
}
