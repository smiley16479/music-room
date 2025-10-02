import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    @State private var showTestView = false
    
    var body: some View {
        NavigationView {
            if authenticationManager.isAuthenticated {
                MainTabView()
                    /* .toolbar {
                        #if DEBUG
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Test") {
                                showTestView = true
                            }
                        }
                        #endif
                    } */
            } else {
                WelcomeView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showTestView) {
            APITestView()
        }
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
