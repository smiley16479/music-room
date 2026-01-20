# MusicRoom iOS Application

Application iOS de collaboration musicale en temps réel développée en SwiftUI.

## Configuration Système

### Prérequis
- **macOS**: Dernière version (Ventura 13.0+ recommandé)
- **Xcode**: Version 15.0+ (compatible avec la dernière version)
- **iOS**: Deployment target iOS 17.0+
- **Swift**: Version 5.9+

## Structure du Projet

```
MusicRoom/
├── MusicRoom.xcodeproj/        # Configuration Xcode
├── MusicRoom/                  # Code source principal
│   ├── MusicRoomApp.swift     # Point d'entrée de l'app
│   ├── ContentView.swift      # Vue principale
│   ├── Core/                  # Fonctionnalités centrales
│   │   ├── Services/         # Services API et authentification
│   │   ├── Theme/            # Gestion des thèmes
│   │   ├── Models/           # Modèles de données
│   │   └── Localization/     # Support multilingue
│   ├── Features/             # Fonctionnalités par domaine
│   │   ├── Authentication/   # Connexion/inscription
│   │   ├── Events/          # Événements musicaux
│   │   ├── Playlists/       # Gestion playlists
│   │   ├── Devices/         # Contrôle périphériques
│   │   └── Profile/         # Profil utilisateur
│   └── Shared/              # Composants réutilisables
└── Localizable.strings/      # Fichiers de traduction
```

## Configuration Avant Build

### 1. Backend Configuration
Modifiez `MusicRoom/Core/Constants.swift` :
```swift
struct API {
    static let baseURL = "https://votre-backend.com/api"  // Remplacer par votre URL
    // ... autres configurations
}
```

### 2. OAuth Configuration
Ajoutez vos clés OAuth dans `Constants.swift` :
```swift
struct OAuth {
    static let googleClientID = "votre_google_client_id"
    static let facebookAppID = "votre_facebook_app_id"
    static let deezerAppID = "votre_deezer_app_id"
}
```

### 3. Team et Bundle Identifier
Dans Xcode :
1. Sélectionnez le projet `MusicRoom`
2. Target `MusicRoom` → Signing & Capabilities
3. Configurez votre Team de développement
4. Modifiez le Bundle Identifier si nécessaire

## Build et Run

### Étapes de Build
1. **Ouvrir le projet**
   ```bash
   open MusicRoom.xcodeproj
   ```

2. **Vérifier la configuration**
   - Target : MusicRoom
   - Deployment Target : iOS 17.0
   - Swift Version : 5.0

3. **Build le projet**
   - Cmd+B pour build
   - Cmd+R pour run

### Simulateurs Recommandés
- iPhone 15 Pro (iOS 17.0+)
- iPhone 14 (iOS 17.0+)
- iPad Air (iOS 17.0+)

## Fonctionnalités Implémentées

### ✅ Authentification
- Connexion email/mot de passe
- Inscription avec validation
- Structure OAuth (Google, Facebook, Deezer)
- Stockage sécurisé avec Keychain

### ✅ Interface Utilisateur
- Thème personnalisé (#FFE2C1, #C6BCFF, #F6A437)
- Mode sombre automatique
- Animations musicales SVG
- Navigation TabView (5 onglets)

### ✅ Internationalisation
- Support Anglais/Français
- Changement de langue en temps réel
- Auto-détection de la langue système

### ✅ Services
- API REST avec gestion d'erreurs
- Socket.IO préparé pour temps réel
- Gestion des tokens JWT avec refresh

### 🔧 À Configurer
- URL backend de production
- Clés OAuth
- Notifications push
- Connexion Socket.IO

## Architecture

### Pattern MVVM
- **Views** : SwiftUI avec @State/@ObservedObject
- **ViewModels** : @ObservableObject avec @Published
- **Models** : Structures de données Codable
- **Services** : Couche d'accès aux données

### Gestion d'État
- `@StateObject` pour les managers principaux
- `@EnvironmentObject` pour le state global
- Combine pour la réactivité

## Tests

### Tests Unitaires
```bash
# Dans Xcode
Cmd+U pour lancer les tests
```

### Tests d'Interface
Tests UI automatisés pour les flows critiques.

## Déploiement

### TestFlight
1. Archive : Product → Archive
2. Distribute App → App Store Connect
3. Upload vers TestFlight

### App Store
Configuration complète pour soumission App Store.

## Dépendances

### Swift Packages
- **SocketIO** : WebSocket temps réel
- Aucune dépendance externe supplémentaire

## Compatibilité

✅ **Compatible avec la dernière version de Xcode sur macOS**
- Xcode 15.0+
- iOS 17.0+ deployment target
- Swift 5.9+
- macOS Ventura 13.0+

## Support et Maintenance

### Logs et Debug
- Console système pour les erreurs réseau
- Breakpoints configurés pour debug
- Logging détaillé des actions utilisateur

### Performance
- Lazy loading des listes
- Cache des images
- Optimisation des re-renders SwiftUI

## Notes de Version

### Version 1.0.0
- Application iOS complète
- Authentification sécurisée
- Interface musicale thématique
- Support multilingue
- Préparation temps réel

---

**Status**: ✅ **Prêt pour build dans la dernière version de Xcode**

L'application est entièrement configurée et compatible avec les dernières versions de macOS et Xcode. Tous les fichiers sont en place, la structure est propre, et le projet peut être buildé immédiatement après avoir configuré les URLs backend et les clés OAuth. App

MusicRoom is a collaborative music application that allows users to create, vote on, and control music together in real-time.

## Features

### 🎵 Core Functionality
- **Music Track Voting**: Live music chain with voting system for tracks
- **Music Playlist Editor**: Real-time collaborative playlist creation
- **Music Control Delegation**: Delegate music control to friends across devices
- **Event Management**: Create and manage music events with voting capabilities

### 🔐 Authentication
- Email/Password registration and login
- Social authentication (Google, Facebook, Deezer OAuth)
- Account linking for multiple social platforms
- Password reset functionality
- Email verification

### 👤 User Management
- User profiles with customizable privacy settings
- Friend system and connections
- Music preferences and recommendations
- Visibility control (Public/Friends Only/Private)

### 🎛️ Device Control
- Device registration and management
- Remote music control delegation
- Multi-device synchronization
- Real-time device status monitoring

### 🌍 Internationalization
- Multi-language support (English/French)
- Automatic language detection
- Runtime language switching

### 🎨 Theme & Design
- Musical theme with custom color palette:
  - Section 1: `#FFE2C1` (Light cream)
  - Section 2: `#C6BCFF` (Light purple)
  - Section 3: `#F6A437` (Orange accent)
- Dark/Light mode support
- Animated musical SVG elements
- Modern SwiftUI design patterns

### 🔔 Notifications
- Push notifications via Socket.IO
- Email notifications (configurable)
- Real-time event updates
- Customizable notification preferences

## Technical Architecture

### 📱 iOS/SwiftUI
- **Minimum iOS Version**: 17.0
- **UI Framework**: SwiftUI with iOS 17+ features
- **Architecture**: MVVM with Combine
- **Navigation**: SwiftUI Navigation with TabView

### 🏗️ Project Structure
```
MusicRoom/
├── Core/
│   ├── Authentication/     # Auth management
│   ├── Services/          # API, Keychain, Socket.IO
│   ├── Theme/             # Theme and styling
│   ├── Localization/      # Multi-language support
│   └── Models/            # Data models
├── Features/
│   ├── Authentication/    # Login/Register screens
│   ├── Home/             # Dashboard and overview
│   ├── Events/           # Event management
│   ├── Playlists/        # Playlist features
│   ├── Devices/          # Device control
│   ├── Profile/          # User profile
│   └── Main/             # Tab navigation
└── Shared/
    └── Components/       # Reusable UI components
```

### 🔗 Backend Integration
- **API**: NestJS REST API
- **Real-time**: Socket.IO integration
- **Authentication**: JWT tokens with refresh
- **Storage**: Keychain for secure token storage

### 🧪 Testing
- Unit tests for core functionality
- UI tests for critical user flows
- TestFlight integration ready
- App Store deployment configured

## API Endpoints

### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/auth/me` - Get current user
- `POST /api/auth/logout` - Sign out
- OAuth routes for Google, Facebook, Deezer

### Music & Events
- `GET /api/events` - Get events
- `POST /api/events` - Create event
- `GET /api/music/search` - Search music
- `GET /api/playlists` - Get playlists
- `POST /api/playlists` - Create playlist

### Devices
- `GET /api/devices/my-devices` - Get user devices
- `POST /api/devices` - Register device
- `POST /api/devices/{id}/delegate` - Delegate control

## Socket.IO Events

### Device Events
- `connect-device` - Connect device
- `update-device-status` - Status updates
- `playback-state` - Music playback info

### Event Management
- `join-event` - Join music event
- `suggest-track` - Suggest track for voting
- `send-message` - Event chat

### Playlist Collaboration
- `join-playlist` - Join collaborative playlist
- `track-drag-preview` - Real-time drag operations
- `update-editing-status` - Live editing status

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ deployment target
- Backend API running (NestJS)

### Configuration
1. Update `APIService.swift` with your backend URL
2. Configure OAuth credentials in `Info.plist`
3. Set up push notification certificates
4. Configure URL schemes for OAuth redirects

### Building
1. Open `MusicRoom.xcodeproj` in Xcode
2. Select target device/simulator
3. Build and run (Cmd+R)

### Testing
- Run unit tests: Cmd+U
- UI tests included for main flows
- TestFlight deployment ready

## Dependencies

### iOS Frameworks
- SwiftUI (UI framework)
- Combine (Reactive programming)
- Foundation (Core functionality)
- Security (Keychain access)

### External Libraries
- Socket.IO client (planned integration)
- OAuth libraries (Google, Facebook, Deezer)

## Localization

### Supported Languages
- English (en) - Default
- French (fr)

### Adding New Languages
1. Add language code to `LocalizationManager.supportedLanguages`
2. Create new `.lproj` folder
3. Add `Localizable.strings` file
4. Update language names dictionary

## Theme Colors

### Light Mode
- **Section1Color**: `#FFE2C1` - Background elements
- **Section2Color**: `#C6BCFF` - Secondary elements  
- **Section3Color**: `#F6A437` - Primary accent

### Dark Mode
- Automatically adapted colors for dark theme
- Maintains musical theme consistency
- High contrast for accessibility

## Permissions

### Required Permissions
- **Microphone**: Music features
- **Location**: Nearby events
- **Contacts**: Friend discovery
- **Photos**: Profile pictures
- **Camera**: Profile picture capture

### Background Modes
- Audio playback
- Background app refresh
- Remote notifications

## Contributing

### Code Style
- Swift 5.0+
- SwiftUI best practices
- MVVM architecture
- Combine for reactive programming

### Commit Guidelines
- Clear, descriptive commit messages
- Feature branches for new functionality
- Code review required for main branch

## License

MusicRoom iOS Application
© 2025 MusicRoom Team

---

For technical support or questions, please contact the development team.
