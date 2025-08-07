import SwiftUI

@main
struct MusicRoomApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var authenticationManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                .environmentObject(authenticationManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
