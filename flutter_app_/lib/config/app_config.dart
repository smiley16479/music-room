/// Application configuration constants
class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://localhost:3000/api';
  static const String wsUrl = 'http://localhost:3000';
  
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
  
  /// Print configuration for debugging
  static void printConfiguration() {
    print('''
    ===== App Configuration =====
    App Name: $appName
    Version: $appVersion
    Base URL: $baseUrl
    WS URL: $wsUrl
    =============================
    ''');
  }
}
