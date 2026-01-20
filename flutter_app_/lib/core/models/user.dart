import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// User model
@JsonSerializable()
class User extends Equatable {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profilePictureUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.profilePictureUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => [firstName, lastName].where((e) => e != null).join(' ');

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        profilePictureUrl,
        createdAt,
        updatedAt,
      ];
}
