import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            if authenticationManager.isAuthenticated {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Initialize app services
            Task {
                authenticationManager.checkAuthenticationStatus()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
        .environmentObject(AuthenticationManager())
}
