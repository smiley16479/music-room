//
//  AppConfig.swift
//  music-room
//
//  Created by adrien on 08/08/2025.
//


import Foundation

struct AppConfig {
    
    // MARK: - Environment
    enum Environment {
        case development
        case staging
        case production
        
        static var current: Environment {
            #if DEBUG
            return .development
            #elseif STAGING
            return .staging
            #else
            return .production
            #endif
        }
    }
    
    // MARK: - API Configuration
    static var baseURL: String {
        switch Environment.current {
        case .development:
            if let base = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_DEV") as? String {
                if base.hasPrefix("http://") || base.hasPrefix("https://") {
                    return base
                } else {
                    return "http://\(base)"
                }
            } else {
                return "http://localhost:3000/api" // fallback
            }
        case .staging:
            return Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_STAGING") as? String ?? "https://staging-api.yourapp.com"
        case .production:
            return Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_PROD") as? String ?? "https://api.yourapp.com"
        }
    }
    
    // MARK: - OAuth Configuration
    static var googleClientId: String {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String else {
            fatalError("GOOGLE_CLIENT_ID not found in Info.plist")
        }
        return clientId
    }
    
    static var googleSchemaIOS: String {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_SCHEMA_IOS") as? String else {
            fatalError("GOOGLE_SCHEMA_IOS not found in Info.plist")
        }
        return clientId
    }
    
    static var facebookAppId: String {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "FACEBOOK_APP_ID") as? String else {
            fatalError("FACEBOOK_APP_ID not found in Info.plist")
        }
        return appId
    }
    
    static var deezerAppId: String {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "DEEZER_APP_ID") as? String else {
            fatalError("DEEZER_APP_ID not found in Info.plist")
        }
        return appId
    }
    
    // MARK: - OAuth Redirect URIs
    static var googleRedirectURI: String {
        let clientIdComponents = googleClientId.components(separatedBy: ".")
        guard let firstComponent = clientIdComponents.first else {
            fatalError("Invalid Google Client ID format")
        }
        return "\(firstComponent):/oauth2redirect/google"
    }
    
    static var facebookRedirectURI: String {
        return "fb\(facebookAppId)://authorize"
    }
    
    static var deezerRedirectURI: String {
        return "deezer\(deezerAppId)://authorize"
    }
    
    // MARK: - OAuth Scopes
    static let googleScopes = "openid email profile"
    static let facebookScopes = "email,public_profile"
    static let deezerScopes = "basic_access,email"
    
    // MARK: - App Information
    static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    static var buildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    
    static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.yourapp.defaultid"
    }
    
    // MARK: - Feature Flags
    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var enableAnalytics: Bool {
        return Bundle.main.object(forInfoDictionaryKey: "ENABLE_ANALYTICS") as? Bool ?? true
    }
    
    static var enableCrashReporting: Bool {
        return Bundle.main.object(forInfoDictionaryKey: "ENABLE_CRASH_REPORTING") as? Bool ?? true
    }
}

// MARK: - Debug Helper
extension AppConfig {
    static func printConfiguration() {
        guard isDebugMode else { return }
        
        print("=== App Configuration ===")
        print("Environment: \(Environment.current)")
        print("Base URL: \(baseURL)")
        print("Google Client ID: \(googleClientId)")
        print("Google Schema IOS: \(googleSchemaIOS)")
        print("Facebook App ID: \(facebookAppId)")
        print("App Version: \(appVersion) (\(buildNumber))")
        print("Bundle ID: \(bundleIdentifier)")
        print("========================")
    }
}
