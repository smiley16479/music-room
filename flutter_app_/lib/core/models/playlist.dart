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
  final String ownerId;
  final User? owner;
  final bool isPublic;
  final int trackCount;
  final int collaboratorCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    this.owner,
    required this.isPublic,
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
        isPublic,
        trackCount,
        collaboratorCount,
        createdAt,
        updatedAt,
      ];
}
