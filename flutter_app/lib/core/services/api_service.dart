import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../utils/exception_handler.dart';
import '../../config/app_config.dart';
import 'keychain_service.dart';

class APIService {
  static final APIService _instance = APIService._internal();

  factory APIService() {
    return _instance;
  }

  APIService._internal();

  final Logger _logger = Logger();
  final KeychainService _keychainService = KeychainService();

  final http.Client _httpClient = http.Client();

  // MARK: - Authentication Endpoints
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
          'displayName': displayName,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      _logger.e('Sign up error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final result = _handleResponse(response);
      
      // Save token
      if (result.containsKey('access_token')) {
        await _keychainService.saveToken(result['access_token']);
      }
      if (result.containsKey('refresh_token')) {
        await _keychainService.saveRefreshToken(result['refresh_token']);
      }

      return result;
    } catch (e) {
      _logger.e('Sign in error: $e');
      rethrow;
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/auth/forgot-password'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email}),
      );

      _handleResponse(response);
    } catch (e) {
      _logger.e('Forgot password error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/auth/logout'),
        headers: await _getAuthenticatedHeaders(),
      );

      await _keychainService.clearAll();
    } catch (e) {
      _logger.e('Sign out error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConfig.baseUrl}/auth/me'),
        headers: await _getAuthenticatedHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      _logger.e('Get current user error: $e');
      rethrow;
    }
  }

  // MARK: - Social Account Linking
  Future<Map<String, dynamic>> linkGoogleAccount({
    required String code,
    required String redirectUri,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/auth/google/mobile-token'),
        headers: await _getAuthenticatedHeaders(),
        body: jsonEncode({
          'code': code,
          'redirectUri': redirectUri,
          'platform': 'android', // or 'ios' depending on platform
          'linkingMode': 'link',
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      _logger.e('Link Google account error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> linkFacebookAccount(String token) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/auth/facebook/mobile-login'),
        headers: await _getAuthenticatedHeaders(),
        body: jsonEncode({
          'access_token': token,
          'linkingMode': 'link',
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      _logger.e('Link Facebook account error: $e');
      rethrow;
    }
  }

  // MARK: - Events Endpoints
  Future<List<dynamic>> getEvents() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConfig.baseUrl}/events'),
        headers: await _getAuthenticatedHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      _logger.e('Get events error: $e');
      rethrow;
    }
  }

  // MARK: - Playlists Endpoints
  Future<List<dynamic>> getPlaylists() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConfig.baseUrl}/playlists'),
        headers: await _getAuthenticatedHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      _logger.e('Get playlists error: $e');
      rethrow;
    }
  }

  // MARK: - Devices Endpoints
  Future<List<dynamic>> getDevices() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConfig.baseUrl}/devices'),
        headers: await _getAuthenticatedHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      _logger.e('Get devices error: $e');
      rethrow;
    }
  }

  // MARK: - Helper Methods
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, String>> _getAuthenticatedHeaders() async {
    final token = await _keychainService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _handleResponse(http.Response response) {
    _logger.d('Response status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        _logger.e('JSON decode error: $e');
        return response.body;
      }
    } else {
      throw APIException(
        statusCode: response.statusCode,
        message: response.body,
      );
    }
  }
}
