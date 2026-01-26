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
  final bool? emailVerified;
  final String? displayNameVisibility;
  final String? bioVisibility;
  final String? birthDateVisibility;
  final String? locationVisibility;
  @JsonKey(fromJson: _musicPreferencesFromJson, toJson: _musicPreferencesToJson)
  final List<String>? musicPreferences;
  final String? musicPreferenceVisibility;
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
    this.emailVerified,
    this.displayNameVisibility,
    this.bioVisibility,
    this.birthDateVisibility,
    this.locationVisibility,
    this.musicPreferences,
    this.musicPreferenceVisibility,
    this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  static List<String>? _musicPreferencesFromJson(dynamic json) {
    if (json == null) return null;
    if (json is List) {
      return json.map((e) => e.toString()).toList();
    }
    if (json is Map) {
      final favoriteGenres = json['favoriteGenres'];
      if (favoriteGenres is List) {
        return favoriteGenres.map((e) => e.toString()).toList();
      }
    }
    return null;
  }

  static dynamic _musicPreferencesToJson(List<String>? preferences) {
    return preferences;
  }

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
        musicPreferences,
        musicPreferenceVisibility,
        lastSeen,        createdAt,
        updatedAt,
      ];
}