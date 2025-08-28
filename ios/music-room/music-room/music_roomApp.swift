//
//  music_roomApp.swift
//  music-room
//
//  Created by adrien on 08/08/2025.
//

import SwiftUI

@main
struct MusicRoomApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var authenticationManager = AuthenticationManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        AppConfig.printConfiguration()
        // _ = SocketService.shared // Initialize the socket service
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                // .environmentObject(SocketService.shared)
                .environmentObject(authenticationManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
