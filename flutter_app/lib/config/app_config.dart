class AppConfig {
  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // API Configuration
  static String get baseUrl {
    const String devUrl = String.fromEnvironment(
      'API_BASE_URL_DEV',
      defaultValue: 'http://localhost:3000/api',
    );

    const String stagingUrl = String.fromEnvironment(
      'API_BASE_URL_STAGING',
      defaultValue: 'https://staging-api.yourapp.com',
    );

    const String prodUrl = String.fromEnvironment(
      'API_BASE_URL_PROD',
      defaultValue: 'https://api.yourapp.com',
    );

    switch (environment) {
      case 'production':
        return prodUrl;
      case 'staging':
        return stagingUrl;
      default:
        return devUrl;
    }
  }

  // OAuth Configuration
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: 'YOUR_GOOGLE_CLIENT_ID',
  );

  static const String facebookAppId = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: 'YOUR_FACEBOOK_APP_ID',
  );

  // Socket Configuration
  static const int socketTimeout = 30000;
  static const int socketReconnectionAttempts = 5;
  static const int socketReconnectionDelay = 3000;
}
