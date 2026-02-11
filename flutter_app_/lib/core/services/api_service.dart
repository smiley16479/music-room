import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../config/app_config.dart';
import '../../config/logger_config.dart';
import 'storage_service.dart';

/// API Service for HTTP requests
class ApiService {
  final SecureStorageService secureStorage;
  final http.Client httpClient;

  ApiService({
    required this.secureStorage,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Get headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await secureStorage.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Check if token is expired
  Future<bool> _isTokenExpired() async {
    final token = await secureStorage.getToken();
    if (token == null) return true;
    return JwtDecoder.isExpired(token);
  }

  /// Refresh token if expired
  Future<void> _refreshTokenIfNeeded() async {
    if (await _isTokenExpired()) {
      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken != null) {
        try {
          await refreshAccessToken(refreshToken);
        } catch (e) {
          logger.e('Token refresh failed: $e');
          rethrow;
        }
      }
    }
  }

  /// Perform GET request
  Future<dynamic> get(String endpoint) async {
    try {
      await _refreshTokenIfNeeded();
      final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      logger.d('GET $url');
      final response = await httpClient.get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      logger.e('GET request error: $e');
      rethrow;
    }
  }

  /// Perform POST request
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
  }) async {
    try {
      await _refreshTokenIfNeeded();
      final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      logger.d('POST $url with body: $body');
      final response = await httpClient.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      logger.e('POST request error: $e');
      rethrow;
    }
  }

  /// Perform PATCH request
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
  }) async {
    try {
      await _refreshTokenIfNeeded();
      final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      logger.d('PATCH $url with body: $body');
      final response = await httpClient.patch(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      logger.e('PATCH request error: $e');
      rethrow;
    }
  }

  /// Perform DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      await _refreshTokenIfNeeded();
      final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final headers = await _getHeaders();

      logger.d('DELETE $url');
      final response = await httpClient.delete(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      logger.e('DELETE request error: $e');
      rethrow;
    }
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    logger.d('Response status: ${response.statusCode}');
    logger.d('Response headers: ${response.headers}');
    logger.d('Response body: ${response.body}');

    dynamic body;
    
    // Handle empty or null responses
    final trimmedBody = response.body.trim();
    if (trimmedBody.isEmpty) {
      body = null;
    } else if (trimmedBody == 'null' || trimmedBody == '"null"') {
      // Handle literal null or quoted null
      body = null;
    } else {
      // Try to parse JSON
      try {
        body = jsonDecode(trimmedBody);
      } catch (e) {
        logger.e('JSON decode error for body: $trimmedBody');
        logger.e('Error: $e');
        
        // If it's a success response with invalid JSON, treat as null
        if (response.statusCode >= 200 && response.statusCode < 300) {
          logger.w('Successful response with invalid JSON, treating as null');
          body = null;
        } else {
          // For error responses, wrap the body as an error message
          body = {'error': 'Invalid JSON', 'message': trimmedBody};
        }
      }
    }
    
    logger.d('Decoded body type: ${body.runtimeType}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (response.statusCode == 403) {
      throw ForbiddenException('Forbidden');
    } else if (response.statusCode == 404) {
      throw NotFoundException('Not found');
    } else if (response.statusCode >= 500) {
      String message = _extractErrorMessage(body);
      throw ServerException(message);
    } else {
      String message = _extractErrorMessage(body);
      throw ApiException(message);
    }
  }

  /// Extract error message from response body (handles different formats)
  String _extractErrorMessage(dynamic body) {
    if (body == null) {
      return 'Unknown error';
    }
    if (body is Map<String, dynamic>) {
      final message = body['message'];
      if (message is String) {
        return message;
      } else if (message is List) {
        // Handle validation error array
        return message.map((e) => e.toString()).join(', ');
      }
      return body['error'] ?? 'Unknown error';
    }
    if (body is String) {
      return body;
    }
    return 'Unknown error';
  }

  /// Auth: Register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return await post(
      '${AppConfig.authEndpoint}/register',
      body: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
  }

  /// Auth: Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return await post(
      '${AppConfig.authEndpoint}/login',
      body: {
        'email': email,
        'password': password,
      },
    );
  }

  /// Auth: Refresh token
  Future<Map<String, dynamic>> refreshAccessToken(String refreshToken) async {
    return await post(
      '${AppConfig.authEndpoint}/refresh',
      body: {'refreshToken': refreshToken},
    );
  }

  /// Auth: Logout
  Future<void> logout() async {
    try {
      // Don't use the regular post method to avoid error logging
      final url = Uri.parse('${AppConfig.baseUrl}${AppConfig.authEndpoint}/logout');
      final headers = await _getHeaders();
      await httpClient.post(url, headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Silently ignore logout errors - we'll clear tokens anyway
    }
    await secureStorage.deleteTokens();
  }

  /// Auth: Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    return await get('${AppConfig.authEndpoint}/me');
  }
}

/// Exception classes
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message);
}

class ForbiddenException extends ApiException {
  ForbiddenException(super.message);
}

class NotFoundException extends ApiException {
  NotFoundException(super.message);
}

class ServerException extends ApiException {
  ServerException(super.message);
}
