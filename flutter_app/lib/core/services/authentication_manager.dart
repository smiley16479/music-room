import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';
import '../services/keychain_service.dart';

class AuthenticationManager extends ChangeNotifier {
  final APIService _apiService = APIService();
  final KeychainService _keychainService = KeychainService();

  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _currentUser != null && _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _keychainService.getToken();
      if (token != null) {
        _token = token;
        // Try to get current user
        final user = await _apiService.getCurrentUser();
        _currentUser = User.fromJson(user);
      }
    } catch (e) {
      _errorMessage = e.toString();
      await _keychainService.clearAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAuthenticationStatus() async {
    await initialize();
  }

  // Sign Up
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      final authResponse = AuthResponse.fromJson(response);
      _token = authResponse.accessToken;
      _currentUser = authResponse.user;

      await _keychainService.saveToken(authResponse.accessToken);
      if (authResponse.refreshToken != null) {
        await _keychainService.saveRefreshToken(authResponse.refreshToken!);
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign In
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.signIn(
        email: email,
        password: password,
      );

      final authResponse = AuthResponse.fromJson(response);
      _token = authResponse.accessToken;
      _currentUser = authResponse.user;

      await _keychainService.saveToken(authResponse.accessToken);
      if (authResponse.refreshToken != null) {
        await _keychainService.saveRefreshToken(authResponse.refreshToken!);
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Forgot Password
  Future<void> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.forgotPassword(email);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.signOut();
      _currentUser = null;
      _token = null;
    } catch (e) {
      _errorMessage = e.toString();
      // Still clear local data
      _currentUser = null;
      _token = null;
      await _keychainService.clearAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Link Google Account
  Future<void> linkGoogleAccount({
    required String code,
    required String redirectUri,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.linkGoogleAccount(
        code: code,
        redirectUri: redirectUri,
      );
      _currentUser = User.fromJson(response);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Link Facebook Account
  Future<void> linkFacebookAccount(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.linkFacebookAccount(token);
      _currentUser = User.fromJson(response);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
