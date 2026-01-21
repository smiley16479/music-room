// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['displayName'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  bio: json['bio'] as String?,
  location: json['location'] as String?,
  birthDate: json['birthDate'] == null
      ? null
      : DateTime.parse(json['birthDate'] as String),
  googleId: json['googleId'] as String?,
  facebookId: json['facebookId'] as String?,
  emailVerified: json['emailVerified'] as bool,
  displayNameVisibility: json['displayNameVisibility'] as String?,
  bioVisibility: json['bioVisibility'] as String?,
  birthDateVisibility: json['birthDateVisibility'] as String?,
  locationVisibility: json['locationVisibility'] as String?,
  lastSeen: json['lastSeen'] == null
      ? null
      : DateTime.parse(json['lastSeen'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'displayName': instance.displayName,
  'avatarUrl': instance.avatarUrl,
  'bio': instance.bio,
  'location': instance.location,
  'birthDate': instance.birthDate?.toIso8601String(),
  'googleId': instance.googleId,
  'facebookId': instance.facebookId,
  'emailVerified': instance.emailVerified,
  'displayNameVisibility': instance.displayNameVisibility,
  'bioVisibility': instance.bioVisibility,
  'birthDateVisibility': instance.birthDateVisibility,
  'locationVisibility': instance.locationVisibility,
  'lastSeen': instance.lastSeen?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
