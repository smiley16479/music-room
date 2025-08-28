import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    // init() {
    //     _ = SocketService.shared // Initialize the socket service
    // }

    var body: some View {
        NavigationView {
            if authenticationManager.isAuthenticated {
                MainTabView()
                // .environmentObject(SocketService.shared)
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
