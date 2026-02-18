import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Auth Provider - manages authentication state
class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  final WebSocketService? webSocketService;
  final DeviceRegistrationService? deviceRegistrationService;
  final NotificationService? notificationService;

  User? _currentUser;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  AuthProvider({
    required this.authService,
    this.webSocketService,
    this.deviceRegistrationService,
    this.notificationService,
  });

  // Getters
  User? get currentUser => _currentUser;
  User? get user => _currentUser; // Alias for easier access
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize - check if user is already logged in
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await authService.getCurrentUser();
      _currentUser = user;
      _isAuthenticated = user != null;
      _error = null;
      // Cache token in memory for quick access
      _token = await authService.secureStorage.getToken();

      // Connect to WebSocket if authenticated
      if (_isAuthenticated && _token != null && webSocketService != null) {
        await webSocketService!.connect(_token!);
        webSocketService!.joinEventsRoom();
        // Initialize global notification service
        notificationService?.initialize();
      }
    } catch (e) {
      _currentUser = null;
      _isAuthenticated = false;
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Register
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      // Don't set _currentUser, _token, or _isAuthenticated
      // User needs to verify email and login manually
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.login(email: email, password: password);
      _token = await authService.secureStorage.getToken();
      _isAuthenticated = true;

      // Connect to WebSocket after successful login
      if (_token != null && webSocketService != null) {
        await webSocketService!.connect(_token!);
        webSocketService!.joinEventsRoom();
        // Initialize global notification service
        notificationService?.initialize();
      }

      // Register device after successful login
      if (deviceRegistrationService != null) {
        final success = await deviceRegistrationService!.registerDevice();
        if (!success) {
          debugPrint('Warning: Device registration failed, but login succeeded');
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update profile
  Future<bool> updateProfile({
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
    _error = null;
    // Don't set _isLoading = true here to avoid triggering a full UI rebuild
    // which would navigate away from the profile screen

    try {
      final updatedUser = await authService.updateProfile(
        displayName: displayName,
        bio: bio,
        location: location,
        birthDate: birthDate,
        displayNameVisibility: displayNameVisibility,
        bioVisibility: bioVisibility,
        locationVisibility: locationVisibility,
        birthDateVisibility: birthDateVisibility,
        musicPreferences: musicPreferences,
        musicPreferenceVisibility: musicPreferenceVisibility,
      );
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await authService.logout();
    } catch (e) {
      // Ignore logout errors, we're clearing state anyway
    }

    // Disconnect WebSocket
    webSocketService?.disconnect();

    _currentUser = null;
    _token = null;
    _isAuthenticated = false;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Google Sign In
  Future<bool> googleSignIn({
    required String idToken,
    String platform = 'web',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.googleSignIn(
        idToken: idToken,
        platform: platform,
      );
      _token = await authService.secureStorage.getToken();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Link Google Account
  Future<bool> linkGoogleAccount({
    required String idToken,
    String platform = 'web',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.linkGoogleAccount(
        idToken: idToken,
        platform: platform,
      );
      _token = await authService.secureStorage.getToken();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Facebook Sign In
  Future<bool> facebookSignIn({required String accessToken}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.facebookSignIn(accessToken: accessToken);
      _token = await authService.secureStorage.getToken();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Link Facebook Account
  Future<bool> linkFacebookAccount({required String accessToken}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.linkFacebookAccount(
        accessToken: accessToken,
      );
      _token = await authService.secureStorage.getToken();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
