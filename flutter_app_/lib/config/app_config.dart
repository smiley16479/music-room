import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Application configuration constants
class AppConfig {
  // API Configuration
  // For development on physical devices: Use your machine's IP (e.g., 192.168.x.x)
  // For iOS Simulator: Try localhost:3000 first, or use your machine IP
  // To find your IP: run `ifconfig` on Mac/Linux or `ipconfig` on Windows
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api'; // Android emulator host machine
    } else {
      return 'http://localhost:3000/api'; // iOS simulator, desktop
    }
  }
  
  // OAuth URL for browser redirects (must be accessible from external browser)
  // IMPORTANT: For Android/iOS, this must be your machine's actual IP address
  // that is accessible from the device's browser, NOT 10.0.2.2 or localhost
  // Run `ifconfig` (Mac/Linux) or `ipconfig` (Windows) to find your IP
  static const String _machineIp = '10.14.6.13'; // TODO: Update with your machine's IP
  
  static String get oauthBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://$_machineIp:3000/api'; // Use actual machine IP for browser
    } else if (Platform.isIOS) {
      return 'http://$_machineIp:3000/api'; // Use actual machine IP for browser
    } else {
      return 'http://localhost:3000/api';
    }
  }
  
  // Frontend URL for OAuth web callbacks (must match FRONTEND_URL in backend .env)
  static String get frontendUrl {
    if (kIsWeb) {
      // Get the current origin for web
      return Uri.base.origin;
    } else {
      return 'http://$_machineIp:5050';
    }
  }
  
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
  static const String playlistsEndpoint = '/playlists';
  static const String tracksEndpoint = '/tracks';
  static const String usersEndpoint = '/users';
  static const String invitationsEndpoint = '/invitations';
  static const String eventsEndpoint = '/events';
  
  // WebSocket Namespaces
  static const String playlistsNamespace = '/playlists';
  static const String eventsNamespace = '/events';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  
  // App Settings
  static const String appName = 'Music Room';
  static const String appVersion = '1.0.0';
  
  // Network timeouts (in seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // OAuth Configuration
  // Google OAuth - Use the Web client ID for authorization code flow
  static const String googleClientId = '734605703797-v6de8ju06pj8nj53d932t2t3isdiotu3.apps.googleusercontent.com';
  // For mobile, you may need platform-specific client IDs:
  // iOS: Configure in google-services.json
  // Android: Configure in google-services.json
  static const String googleRedirectUri = 'http://localhost:3000/api/auth/google/callback';
  
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
    Google Client ID: $googleClientId
    Facebook App ID: $facebookAppId
    =============================
    ''');
  }
}
