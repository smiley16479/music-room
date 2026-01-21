import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Auth Provider - manages authentication state
class AuthProvider extends ChangeNotifier {
  final AuthService authService;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  AuthProvider({required this.authService});

  // Getters
  User? get currentUser => _currentUser;
  User? get user => _currentUser; // Alias for easier access
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
    String? firstName,
    String? lastName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
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

  /// Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.login(
        email: email,
        password: password,
      );
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

  /// Update profile
  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? location,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await authService.updateProfile(
        displayName: displayName,
        bio: bio,
        location: location,
      );
      _currentUser = updatedUser;
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

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await authService.logout();
      _currentUser = null;
      _isAuthenticated = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Google Sign In
  Future<bool> googleSignIn({
    required String code,
    required String redirectUri,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.googleSignIn(
        code: code,
        redirectUri: redirectUri,
        platform: 'web',
      );
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
  Future<bool> facebookSignIn({
    required String accessToken,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await authService.facebookSignIn(
        accessToken: accessToken,
      );
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