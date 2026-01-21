import 'package:jwt_decoder/jwt_decoder.dart';

import '../models/index.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Authentication Service - manages authentication state and operations
class AuthService {
  final ApiService apiService;
  final SecureStorageService secureStorage;

  AuthService({
    required this.apiService,
    required this.secureStorage,
  });

  /// Register new user
  Future<User> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final response = await apiService.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );

    final userData = response['data'] as Map<String, dynamic>;
    return User.fromJson(userData);
  }

  /// Login user
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await apiService.login(
      email: email,
      password: password,
    );

    final data = response['data'] as Map<String, dynamic>;
    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    final userData = data['user'] as Map<String, dynamic>;

    // Save tokens
    await secureStorage.saveToken(token);
    if (refreshToken != null) {
      await secureStorage.saveRefreshToken(refreshToken);
    }

    return User.fromJson(userData);
  }

  /// Logout user
  Future<void> logout() async {
    await apiService.logout();
    await secureStorage.deleteTokens();
  }

  /// Get current user
  Future<User?> getCurrentUser() async {
    try {
      final hasToken = await secureStorage.hasToken();
      if (!hasToken) return null;

      final response = await apiService.getCurrentUser();
      final userData = response['data'] as Map<String, dynamic>;
      return User.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  /// Check if user is authenticated
  /// Update user profile
  Future<User> updateProfile({
    String? displayName,
    String? bio,
    String? location,
  }) async {
    final response = await apiService.patch(
      '/users/me',
      body: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (location != null) 'location': location,
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<bool> isAuthenticated() async {
    return await secureStorage.hasToken();
  }

  /// Get user ID from token
  Future<String?> getUserIdFromToken() async {
    try {
      final token = await secureStorage.getToken();
      if (token == null) return null;

      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['sub'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Google Sign In
  Future<User> googleSignIn({
    required String code,
    required String redirectUri,
    String platform = 'web',
  }) async {
    final response = await apiService.post(
      '/auth/google/mobile-token',
      body: {
        'code': code,
        'redirectUri': redirectUri,
        'platform': platform,
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    final userData = data['user'] as Map<String, dynamic>;

    // Save tokens
    await secureStorage.saveToken(token);
    if (refreshToken != null) {
      await secureStorage.saveRefreshToken(refreshToken);
    }

    return User.fromJson(userData);
  }

  /// Facebook Sign In
  Future<User> facebookSignIn({
    required String accessToken,
  }) async {
    final response = await apiService.post(
      '/auth/facebook/mobile-token',
      body: {
        'accessToken': accessToken,
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    final userData = data['user'] as Map<String, dynamic>;

    // Save tokens
    await secureStorage.saveToken(token);
    if (refreshToken != null) {
      await secureStorage.saveRefreshToken(refreshToken);
    }

    return User.fromJson(userData);
  }
}