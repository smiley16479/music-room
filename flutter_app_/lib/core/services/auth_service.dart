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
    required String displayName,
  }) async {
    final response = await apiService.register(
      email: email,
      password: password,
      displayName: displayName,
    );
  
    final data = response['data'] as Map<String, dynamic>;
    final userJson = data['user'] as Map<String, dynamic>;
  
    // Don't save tokens - user needs to verify email first
    // The backend sends tokens but we ignore them for registration
  
    return User.fromJson(userJson);
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
      // If 401 or any auth error, clear tokens and return null
      if (e.toString().contains('Unauthorized') || e.toString().contains('401')) {
        await secureStorage.deleteTokens();
      }
      return null;
    }
  }

  /// Check if user is authenticated
  /// Update user profile
  Future<User> updateProfile({
    String? displayName,
    String? bio,
    String? location,
    String? birthDate,
    String? displayNameVisibility,
    String? bioVisibility,
    String? locationVisibility,
    String? birthDateVisibility,
    List<String>? musicPreferences,
    String? musicPreferenceVisibility,
  }) async {
    final response = await apiService.patch(
      '/users/me',
      body: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (location != null) 'location': location,
        if (birthDate != null) 'birthDate': birthDate,
        if (displayNameVisibility != null) 'displayNameVisibility': displayNameVisibility,
        if (bioVisibility != null) 'bioVisibility': bioVisibility,
        if (locationVisibility != null) 'locationVisibility': locationVisibility,
        if (birthDateVisibility != null) 'birthDateVisibility': birthDateVisibility,
        if (musicPreferences != null) 'musicPreferences': {'favoriteGenres': musicPreferences},
        if (musicPreferenceVisibility != null) 'musicPreferenceVisibility': musicPreferenceVisibility,
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
    required String idToken,
    String platform = 'web',
  }) async {
    final response = await apiService.post(
      '/auth/google/id-token',
      body: {
        'idToken': idToken,
        'platform': platform,
      },
    );

    final token = response['accessToken'] as String;
    final refreshToken = response['refreshToken'] as String?;
    final userData = response['user'] as Map<String, dynamic>;

    // Save tokens
    await secureStorage.saveToken(token);
    if (refreshToken != null) {
      await secureStorage.saveRefreshToken(refreshToken);
    }

    return User.fromJson(userData);
  }

  /// Link Google Account
  Future<User> linkGoogleAccount({
    required String idToken,
    String platform = 'web',
  }) async {
    final response = await apiService.post(
      '/auth/google/id-token',
      body: {
        'idToken': idToken,
        'platform': platform,
        'linkingMode': 'link',
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    return User.fromJson(data);
  }

  /// Facebook Sign In
  Future<User> facebookSignIn({
    required String accessToken,
  }) async {
    final response = await apiService.post(
      '/auth/facebook/mobile-login',
      body: {
        'access_token': accessToken,
      },
    );

    final token = response['accessToken'] as String;
    final refreshToken = response['refreshToken'] as String?;
    final userData = response['user'] as Map<String, dynamic>;

    // Save tokens
    await secureStorage.saveToken(token);
    if (refreshToken != null) {
      await secureStorage.saveRefreshToken(refreshToken);
    }

    return User.fromJson(userData);
  }

  /// Link Facebook Account
  Future<User> linkFacebookAccount({
    required String accessToken,
  }) async {
    final response = await apiService.post(
      '/auth/facebook/mobile-login',
      body: {
        'access_token': accessToken,
        'linkingMode': 'link',
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    return User.fromJson(data);
  }
}