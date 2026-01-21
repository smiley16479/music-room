import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'playlist.g.dart';

/// Playlist model
@JsonSerializable()
class Playlist extends Equatable {
  final String id;
  final String name;
  final String? description;
  @JsonKey(name: 'creatorId')
  final String? ownerId;
  @JsonKey(name: 'creator')
  final User? owner;
  @JsonKey(name: 'visibility')
  final String? visibility;
  @JsonKey(fromJson: _trackCountFromJson)
  final int trackCount;
  @JsonKey(fromJson: _collaboratorCountFromJson)
  final int collaboratorCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.ownerId,
    this.owner,
    this.visibility,
    required this.trackCount,
    required this.collaboratorCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => _$PlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        ownerId,
        owner,
        visibility,
        trackCount,
        collaboratorCount,
        createdAt,
        updatedAt,
      ];
}

// Helper functions to extract counts from either direct fields or stats object
int _trackCountFromJson(dynamic value) {
  if (value is int) return value;
  return 0;
}

int _collaboratorCountFromJson(dynamic value) {
  if (value is int) return value;
  return 0;
}
