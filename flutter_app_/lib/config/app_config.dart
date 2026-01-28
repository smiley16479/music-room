import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Application configuration constants
///
/// MOBILE OAUTH: Uses native SDKs (Google Sign-In, Facebook Login)
/// - No browser redirect needed for mobile
/// - Native SDKs handle authentication directly in the app
/// - Only web uses browser-based OAuth flow
///
/// NETWORK ACCESS:
/// - For Android emulator: Use 10.0.2.2 to access host machine's localhost
/// - For physical devices: Use your machine's actual IP address
/// - For web: localhost works directly
class AppConfig {
  // Machine IP for physical device testing
  // Run `ifconfig` (Mac/Linux) or `ipconfig` (Windows) to find your IP
  // ignore: unused_field
  static const String _machineIp = '10.16.13.5';

  // API Configuration
  // For Android emulator: 10.0.2.2 maps to host's localhost
  // For physical devices: use machine IP
  // For web: localhost works directly
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      // For emulator use 10.0.2.2, for physical device use _machineIp
      return 'http://10.0.2.2:3000/api';
    } else {
      // iOS simulator can use localhost, physical device needs machine IP
      return 'http://localhost:3000/api';
    }
  }

  // OAuth URL - only used for web (mobile uses native SDKs)
  static String get oauthBaseUrl {
    // Only web uses browser-based OAuth
    return 'http://localhost:3000/api';
  }

  // Frontend URL for OAuth web callbacks (must match FRONTEND_URL in backend .env)
  static String get frontendUrl {
    if (kIsWeb) {
      // Get the current origin for web
      return Uri.base.origin;
    } else {
      // Not used for mobile OAuth (native SDKs don't need this)
      return 'http://localhost:5050';
    }
  }

  // WebSocket URL for real-time features
  static String get wsUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'http://localhost:3000';
    }
  }

  // API Endpoints
  static const String authEndpoint = '/auth';
  static const String tracksEndpoint = '/tracks';
  static const String usersEndpoint = '/users';
  static const String invitationsEndpoint = '/invitations';
  static const String eventsEndpoint =
      '/events'; // Unified endpoint for events and playlists

  // WebSocket Namespaces
  static const String eventsNamespace =
      '/events'; // Unified namespace for events and playlists

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';

  // App Settings
  static const String appName = 'Music Room';
  static const String appVersion = '1.0.0';

  // Debug Settings
  /// Set to true to skip authentication and go directly to HomeScreen
  /// ⚠️ WARNING: Set to false in production!
  static const bool debugSkipAuth = false;

  // Network timeouts (in seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;

  // Pagination
  static const int defaultPageSize = 20;

  // OAuth Configuration
  // Google OAuth - Different client IDs for different platforms
  // Web: Web client ID (for browser-based OAuth)
  // Android: Android client ID (for native Google Sign-In SDK)
  // iOS: iOS client ID (for native Google Sign-In SDK)
  static const String _googleWebClientId =
      '46787990233-v5nevke1f34dbjchgcc20sl8u7bvutaq.apps.googleusercontent.com';
  static const String _googleAndroidClientId =
      '46787990233-c17r22jnabf1t2rgmev5grs056utdes0.apps.googleusercontent.com';
  static const String _googleIosClientId =
      '46787990233-v0pg16vpkk8d82edjjea9ltmgq0lf9se.apps.googleusercontent.com';

  static String get googleClientId {
    if (kIsWeb) {
      return _googleWebClientId;
    } else if (Platform.isAndroid) {
      return _googleAndroidClientId;
    } else if (Platform.isIOS) {
      return _googleIosClientId;
    }
    return _googleWebClientId;
  }

  // Explicit getters for each platform
  static String get googleWebClientId => _googleWebClientId;
  static String get googleAndroidClientId => _googleAndroidClientId;
  static String get googleIosClientId => _googleIosClientId;

  // For mobile, you may need platform-specific client IDs:
  // iOS: Configure in google-services.json
  // Android: Configure in google-services.json
  static const String googleRedirectUri =
      'http://localhost:3000/api/auth/google/callback';

  // Facebook OAuth
  static const String facebookAppId = '1288105682888984';

  /// Print configuration for debugging
  static void printConfiguration() {
    print('''
    ===== App Configuration =====
    App Name: $appName
    Version: $appVersion
    Base URL: $baseUrl
    WS URL: $wsUrl
    Debug Skip Auth: $debugSkipAuth
    Google Client ID: $googleClientId
    Facebook App ID: $facebookAppId
    =============================
    ''');
  }
}
