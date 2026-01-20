# Music Room Flutter Application

A cross-platform Flutter mobile application for collaborative music management, rebuilt from the original Swift iOS app.

## Features

- **Authentication**
  - Email/Password Sign In and Sign Up
  - Forgot Password functionality
  - Social account linking (Google, Facebook)
  - Secure token storage with Keychain

- **Music Management**
  - Create and manage playlists
  - Vote on tracks in events
  - Collaborative music editing
  - Real-time updates via WebSocket

- **Device Management**
  - Connect and manage multiple devices
  - Delegate music control to other devices
  - Monitor device status and connections

- **User Profile**
  - View and manage profile information
  - Linked social accounts
  - Account settings

## Project Structure

```
lib/
├── config/
│   └── app_config.dart           # Configuration management
├── core/
│   ├── models/
│   │   ├── auth_models.dart      # Authentication data models
│   │   └── music_models.dart     # Music-related models
│   ├── services/
│   │   ├── api_service.dart      # REST API client
│   │   ├── keychain_service.dart # Secure token storage
│   │   └── authentication_manager.dart # Auth state management
│   ├── theme/
│   │   └── theme_manager.dart    # Theme and dark mode
│   └── utils/
│       └── exception_handler.dart # Custom exceptions
├── features/
│   ├── authentication/
│   │   └── views/
│   │       ├── welcome_view.dart
│   │       ├── sign_in_view.dart
│   │       ├── sign_up_view.dart
│   │       └── forgot_password_view.dart
│   ├── home/
│   │   └── views/
│   │       └── home_view.dart    # Main app navigation
│   ├── events/
│   ├── playlists/
│   ├── devices/
│   └── profile/
│       └── views/
│           └── profile_view.dart
└── main.dart                      # App entry point
```

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (included with Flutter)
- Android SDK (for Android development)
- Xcode (for iOS development)
- NestJS Backend running at `http://localhost:3000/api` (development)

## Getting Started

### 1. Install Dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Configure Environment

Update `lib/config/app_config.dart` with your backend API URL and OAuth credentials:

```dart
static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID';
static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
```

### 3. Run the Application

**For Android:**
```bash
flutter run
```

**For iOS:**
```bash
flutter run -d iphone
```

**For Web (Chrome):**
```bash
flutter run -d chrome
```

## Dependencies

- **State Management**: Provider
- **HTTP Client**: http, socket_io_client
- **Storage**: shared_preferences
- **Authentication**: google_sign_in, flutter_facebook_auth
- **Audio**: just_audio
- **UI**: google_fonts
- **Logging**: logger
- **Serialization**: json_serializable

## API Endpoints

The app communicates with a NestJS backend at the configured base URL. Key endpoints:

### Authentication
- `POST /auth/register` - Sign up
- `POST /auth/login` - Sign in
- `POST /auth/logout` - Sign out
- `POST /auth/forgot-password` - Request password reset
- `GET /auth/me` - Get current user
- `POST /auth/google/mobile-token` - Link Google account
- `POST /auth/facebook/mobile-login` - Link Facebook account

### Music Management
- `GET /playlists` - Get all playlists
- `GET /events` - Get all events
- `GET /devices` - Get all devices

## Architecture

The app uses a clean architecture pattern with:

- **Models**: Data structures for API requests/responses
- **Services**: Business logic and API communication
- **Managers**: State management using Provider
- **Views**: UI screens and widgets
- **Themes**: Centralized theming and localization

## Building for Production

### Android

```bash
flutter build apk
# or for app bundle
flutter build appbundle
```

### iOS

```bash
flutter build ios
```

### Web

```bash
flutter build web
```

## Troubleshooting

### API Connection Issues
- Ensure the backend is running at the configured URL
- Check your internet connection
- Verify firewall settings

### Authentication Issues
- Clear app cache: `flutter clean`
- Verify OAuth credentials are correct
- Check token expiration

### Build Issues
- Run `flutter clean` to remove build artifacts
- Update Flutter: `flutter upgrade`
- Get fresh dependencies: `flutter pub get`

## Development

### Hot Reload
Press `r` in the terminal while the app is running to reload without restarting.

### Debug Mode
Run with verbose logging:
```bash
flutter run -v
```

### Testing
```bash
flutter test
```

## Contributing

When adding new features:
1. Follow the existing project structure
2. Use the Provider pattern for state management
3. Add error handling and logging
4. Update this README with any new features

## Future Enhancements

- [ ] Real-time WebSocket implementation for live updates
- [ ] Music player UI
- [ ] Offline mode with local caching
- [ ] Push notifications
- [ ] Internationalization (i18n)
- [ ] Unit and integration tests
- [ ] CI/CD pipeline

## License

This project is part of the Music Room application suite.
