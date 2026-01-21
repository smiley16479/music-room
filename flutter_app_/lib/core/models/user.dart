import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// User model
@JsonSerializable()
class User extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final DateTime? birthDate;
  final String? googleId;
  final String? facebookId;
  final bool emailVerified;
  final String? displayNameVisibility;
  final String? bioVisibility;
  final String? birthDateVisibility;
  final String? locationVisibility;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.birthDate,
    this.googleId,
    this.facebookId,
    required this.emailVerified,
    this.displayNameVisibility,
    this.bioVisibility,
    this.birthDateVisibility,
    this.locationVisibility,
    this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        avatarUrl,
        bio,
        location,
        birthDate,
        googleId,
        facebookId,
        emailVerified,
        displayNameVisibility,
        bioVisibility,
        birthDateVisibility,
        locationVisibility,
        lastSeen,        createdAt,
        updatedAt,
      ];
}