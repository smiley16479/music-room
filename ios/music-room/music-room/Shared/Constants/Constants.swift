import Foundation
import SwiftUI

// MARK: - App Constants
struct AppConstants {
    
    // MARK: - API Configuration
    struct API {
        static let baseURL = "http://localhost:3000/api" // TODO: Replace with production URL
        static let socketURL = "http://localhost:3000" // TODO: Replace with production URL
        static let timeout: TimeInterval = 30.0
        static let maxRetries = 3
    }
    
    // MARK: - OAuth Configuration
    struct OAuth {
        static let googleClientID = "734605703797-duvg1eiupfeva2njit9chbpq0bvmstke.apps.googleusercontent.com"
        static let facebookAppID = "1288105682888984"
        static let deezerAppID = "" // TODO: Add Deezer App ID
        
        // URL Schemes
        static let urlScheme = "musicroom"
        static let googleRedirectURL = "\(urlScheme)://oauth/google"
        static let facebookRedirectURL = "\(urlScheme)://oauth/facebook"
        static let deezerRedirectURL = "\(urlScheme)://oauth/deezer"
    }
    
    // MARK: - UI Configuration
    struct UI {
        // Animation Durations
        static let shortAnimation: Double = 0.2
        static let mediumAnimation: Double = 0.3
        static let longAnimation: Double = 0.5
        
        // Spacing
        static let smallSpacing: CGFloat = 8
        static let mediumSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
        static let extraLargeSpacing: CGFloat = 32
        
        // Corner Radius
        static let smallCornerRadius: CGFloat = 8
        static let mediumCornerRadius: CGFloat = 12
        static let largeCornerRadius: CGFloat = 16
        static let extraLargeCornerRadius: CGFloat = 20
        
        // Button Heights
        static let buttonHeight: CGFloat = 56
        static let smallButtonHeight: CGFloat = 40
        static let largeButtonHeight: CGFloat = 64
        
        // Icon Sizes
        static let smallIconSize: CGFloat = 16
        static let mediumIconSize: CGFloat = 24
        static let largeIconSize: CGFloat = 32
        static let extraLargeIconSize: CGFloat = 48
        
        // Card Settings
        static let cardPadding: CGFloat = 16
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowOpacity: Double = 0.1
    }
    
    // MARK: - Music Configuration
    struct Music {
        static let maxPlaylistTracks = 1000
        static let maxEventDuration: TimeInterval = 24 * 60 * 60 // 24 hours
        static let votingCooldown: TimeInterval = 5.0 // 5 seconds
        static let trackPreviewDuration: TimeInterval = 30.0 // 30 seconds
        
        // Deezer Configuration
        static let deezerAPIBase = "https://api.deezer.com"
        static let defaultAlbumCover = "https://via.placeholder.com/300x300/f6a437/ffffff?text=♪"
    }
    
    // MARK: - Validation Rules
    struct Validation {
        static let minPasswordLength = 6
        static let maxPasswordLength = 128
        static let minDisplayNameLength = 2
        static let maxDisplayNameLength = 30
        static let maxBioLength = 500
        static let maxEventNameLength = 100
        static let maxPlaylistNameLength = 100
        static let maxDeviceNameLength = 50
    }
    
    // MARK: - Device Types
    static let supportedDeviceTypes: [DeviceType] = [
        .speaker, .phone, .computer, .tablet, .other
    ]
    
    // MARK: - Notification Configuration
    struct Notifications {
        static let categories = [
            "EVENT_INVITATION",
            "PLAYLIST_UPDATE", 
            "FRIEND_REQUEST",
            "MUSIC_RECOMMENDATION",
            "VOTE_UPDATE",
            "DEVICE_DELEGATION"
        ]
        
        static let defaultSound = "default"
        static let criticalSound = "critical"
    }
    
    // MARK: - Cache Configuration
    struct Cache {
        static let imageCache = "ImageCache"
        static let musicCache = "MusicCache"
        static let userCache = "UserCache"
        static let maxCacheSize: Int = 100 * 1024 * 1024 // 100 MB
        static let cacheExpiry: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let networkUnavailable = "Network connection unavailable"
        static let authenticationFailed = "Authentication failed"
        static let invalidCredentials = "Invalid email or password"
        static let serverError = "Server error occurred"
        static let timeoutError = "Request timed out"
        static let unknownError = "An unknown error occurred"
    }
    
    // MARK: - Socket Events
    struct SocketEvents {
        // Device Events
        static let connectDevice = "connect-device"
        static let disconnectDevice = "disconnect-device"
        static let updateDeviceStatus = "update-device-status"
        static let playbackState = "playback-state"
        
        // Event Events
        static let joinEvent = "join-event"
        static let leaveEvent = "leave-event"
        static let suggestTrack = "suggest-track"
        static let voteTrack = "vote-track"
        
        // Playlist Events
        static let joinPlaylist = "join-playlist"
        static let leavePlaylist = "leave-playlist"
        static let trackOperation = "start-track-operation"
        static let trackDragPreview = "track-drag-preview"
        
        // General Events
        static let heartbeat = "heartbeat"
        static let sendMessage = "send-message"
    }
    
    // MARK: - User Defaults Keys
    struct UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let preferredLanguage = "preferredLanguage"
        static let isDarkModeEnabled = "isDarkModeEnabled"
        static let pushNotificationsEnabled = "pushNotificationsEnabled"
        static let emailNotificationsEnabled = "emailNotificationsEnabled"
        static let lastSyncTimestamp = "lastSyncTimestamp"
        static let musicQuality = "musicQuality"
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let isDebugging = false
        static let enableBetaFeatures = false
        static let enableAnalytics = true
        static let enableCrashReporting = true
        static let enablePerformanceMonitoring = true
        static let mockAPIResponses = false
    }
    
    // MARK: - App Store Configuration
    struct AppStore {
        static let appID = "" // TODO: Add App Store ID
        static let reviewURL = "https://apps.apple.com/app/id\(appID)?action=write-review"
        static let supportEmail = "support@musicroom.com"
        static let privacyPolicyURL = "https://musicroom.com/privacy"
        static let termsOfServiceURL = "https://musicroom.com/terms"
    }
    
    // MARK: - Development Configuration
    #if DEBUG
    struct Debug {
        static let enableNetworkLogging = true
        static let enableUITesting = true
        static let skipAuthentication = false
        static let useMockData = false
        static let showDebugInfo = true
    }
    #endif
}

// MARK: - Theme Constants
extension AppConstants {
    struct Theme {
        // Main Colors (from specifications)
        static let section1Color = Color(hex: "FFE2C1") // #FFE2C1
        static let section2Color = Color(hex: "C6BCFF") // #C6BCFF
        static let section3Color = Color(hex: "F6A437") // #F6A437
        
        // Semantic Colors
        static let primaryColor = section3Color
        static let secondaryColor = section2Color
        static let backgroundColor = section1Color
        static let accentColor = primaryColor
        
        // Status Colors
        static let successColor = Color.green
        static let errorColor = Color.red
        static let warningColor = Color.orange
        static let infoColor = Color.blue
        
        // Gradient Definitions
        static let primaryGradient = LinearGradient(
            gradient: Gradient(colors: [primaryColor, secondaryColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let backgroundGradient = LinearGradient(
            gradient: Gradient(colors: [
                backgroundColor.opacity(0.8),
                secondaryColor.opacity(0.6),
                primaryColor.opacity(0.4)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Shadow Definitions
        static let cardShadow = Color.black.opacity(0.05)
        static let heavyShadow = Color.black.opacity(0.15)
        
        // Typography
        struct Typography {
            static let titleFont = Font.largeTitle.weight(.bold)
            static let headlineFont = Font.title2.weight(.semibold)
            static let bodyFont = Font.body
            static let captionFont = Font.caption
            static let buttonFont = Font.headline.weight(.medium)
        }
    }
}

// MARK: - Music Constants
extension AppConstants {
    struct MusicGenres {
        static let all = [
            "Pop", "Rock", "Hip-Hop", "Electronic", "Jazz", "Classical",
            "R&B", "Country", "Folk", "Blues", "Reggae", "Latin",
            "World", "Alternative", "Indie", "Metal", "Punk", "Funk",
            "Soul", "Gospel", "House", "Techno", "Ambient", "Experimental"
        ]
    }
    
    struct AudioFormats {
        static let supportedFormats = ["mp3", "aac", "wav", "m4a"]
        static let preferredFormat = "mp3"
        static let bitrates = [128, 192, 256, 320] // kbps
        static let defaultBitrate = 192
    }
}
