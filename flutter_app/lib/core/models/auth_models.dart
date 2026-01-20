class User {
  final String id;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final String? googleId;
  final String? facebookId;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.googleId,
    this.facebookId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      googleId: json['googleId'],
      facebookId: json['facebookId'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'googleId': googleId,
      'facebookId': facebookId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class AuthResponse {
  final String accessToken;
  final String? refreshToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? json['accessToken'] ?? '',
      refreshToken: json['refresh_token'] ?? json['refreshToken'],
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}
