<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# MusicRoom iOS Development Instructions

## Project Overview
This is a SwiftUI iOS application for collaborative music experiences, featuring real-time playlist collaboration, music voting, and device control delegation.

## Architecture & Patterns
- **UI Framework**: SwiftUI with iOS 17+ features
- **Architecture**: MVVM pattern with Combine for reactive programming
- **State Management**: @StateObject, @ObservableObject, @Published properties
- **Navigation**: SwiftUI Navigation with TabView for main navigation

## Code Style Guidelines

### SwiftUI Best Practices
- Use `@State` for local view state
- Use `@StateObject` for creating ObservableObject instances
- Use `@ObservedObject` for passing ObservableObject instances
- Use `@EnvironmentObject` for shared app-wide state
- Prefer `@ViewBuilder` for custom view builders
- Use `@MainActor` for UI updates in async contexts

### Naming Conventions
- Views: PascalCase ending with "View" (e.g., `HomeView`, `EventListView`)
- View Models: PascalCase ending with "Manager" or "ViewModel"
- Models: PascalCase (e.g., `User`, `Event`, `Playlist`)
- Properties: camelCase
- Constants: UPPER_SNAKE_CASE for static constants

### File Organization
```
- Core/: Core functionality, services, themes, models
- Features/: Feature-specific views and logic organized by domain
- Shared/: Reusable components and utilities
```

## Key Technologies

### Backend Integration
- **API Service**: REST API communication with NestJS backend
- **Socket.IO**: Real-time communication (WebSockets)
- **Authentication**: JWT tokens with refresh mechanism
- **Keychain**: Secure token storage

### Localization
- Support for English (en) and French (fr)
- Use `"key".localized` for translated strings
- Runtime language switching capability
- Auto-detection of system language

### Theme System
- **Colors**: 
  - Section1Color: #FFE2C1 (cream background)
  - Section2Color: #C6BCFF (purple secondary)  
  - Section3Color: #F6A437 (orange primary)
- **Dark Mode**: Automatic adaptation with theme manager
- **Musical Elements**: Animated SVG-style components

### Authentication Flow
- Email/Password with validation
- Social OAuth (Google, Facebook, Deezer)
- Account linking capabilities
- Password reset with email verification

## Data Models

### Core Entities
- **User**: Profile, preferences, privacy settings
- **Event**: Music voting events with location/time constraints  
- **Playlist**: Collaborative music playlists
- **Track**: Music tracks from Deezer API
- **Device**: Music playback devices for delegation
- **Vote**: User votes on tracks in events

### Permissions & Visibility
- **VisibilityLevel**: public, friendsOnly, private
- **LicenseType**: open, invited, locationBased
- **EventStatus**: upcoming, active, paused, ended

## Real-time Features

### Socket.IO Events
- Device connection and status updates
- Event participation and voting
- Playlist collaboration with live editing
- Message systems for events and playlists

### State Synchronization
- Real-time UI updates for collaborative features
- Conflict resolution for simultaneous edits
- Live status indicators for devices and events

## UI Components

### Reusable Components
- `CustomTextField`: Styled text input with icons
- `CustomSecureField`: Password input with show/hide toggle
- `SocialLoginButton`: OAuth authentication buttons
- `CardView`: Consistent card styling
- `LoadingView`, `ErrorView`, `EmptyStateView`: State management

### Navigation
- `MainTabView`: 5-tab navigation (Home, Events, Playlists, Devices, Profile)
- Sheet presentations for forms and detailed views
- NavigationView with proper title styling

## Error Handling
- `APIError` enum for consistent error types
- User-friendly error messages with localization
- Toast notifications for non-blocking feedback
- Alert dialogs for critical actions

## Testing Strategy
- Unit tests for ViewModels and Services
- UI tests for critical user flows
- Mock services for testing
- TestFlight configuration for beta testing

## Performance Considerations
- Lazy loading for lists and grids
- Image caching for album covers and avatars
- Efficient state updates with Combine
- Background task management for real-time features

## Security
- Keychain storage for sensitive data
- Token refresh mechanism
- OAuth security best practices
- Privacy controls for user data

## Development Workflow
- Feature branches for new functionality
- Code review process
- Incremental feature implementation
- Regular testing and validation

When working on this project:
1. Follow SwiftUI and iOS best practices
2. Maintain consistency with existing patterns
3. Use proper error handling and user feedback
4. Consider real-time collaboration requirements
5. Test thoroughly with different states and edge cases
6. Ensure accessibility and localization support
