/// Application configuration constants
class AppConfig {
  // API Configuration
  // For development on physical devices: Use your machine's IP (e.g., 192.168.x.x)
  // For iOS Simulator: Try localhost:3000 first, or use your machine IP
  // To find your IP: run `ifconfig` on Mac/Linux or `ipconfig` on Windows
  static const String baseUrl = 'http://10.16.13.1:3000/api';
  static const String wsUrl = 'http://10.16.13.1:3000';
  
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
  
  // Debug Settings
  /// Set to true to skip authentication and go directly to HomeScreen
  /// ⚠️ WARNING: Set to false in production!
  static const bool debugSkipAuth = false;
  
  // Network timeouts (in seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  
  // Pagination
  static const int defaultPageSize = 20;
  
  /// Print configuration for debugging
  static void printConfiguration() {
    print('''
    ===== App Configuration =====
    App Name: $appName
    Version: $appVersion
    Base URL: $baseUrl
    WS URL: $wsUrl
    Debug Skip Auth: $debugSkipAuth
    =============================
    ''');
  }
}
