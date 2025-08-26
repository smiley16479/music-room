import SwiftUI

class MainTabManager: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var selectedPlaylist: Playlist? = nil
}

struct MainTabView: View {
    @StateObject private var tabManager = MainTabManager()
    
    var body: some View {
        // NavigationView {
            TabView(selection: $tabManager.selectedTab) {
                HomeView2()
                    .environmentObject(tabManager)
                    .tabItem {
                        Image(systemName: tabManager.selectedTab == 0 ? "house.fill" : "house")
                        Text("home".localized)
                    }
                    .tag(0)
                
                EventsView()
                    .environmentObject(tabManager)
                    .tabItem {
                        Image(systemName: tabManager.selectedTab == 1 ? "calendar.circle.fill" : "calendar.circle")
                        Text("events".localized)
                    }
                    .tag(1)
                
                PlaylistsView()
                    .environmentObject(tabManager)
                    .tabItem {
                        Image(systemName: tabManager.selectedTab == 2 ? "music.note.list" : "music.note.list")
                        Text("playlists".localized)
                    }
                    .tag(2)
                
                DevicesView()
                    .tabItem {
                        Image(systemName: tabManager.selectedTab == 3 ? "speaker.wave.3.fill" : "speaker.wave.3")
                        Text("devices".localized)
                    }
                    .tag(3)
                
                ProfileView()
                    .environmentObject(tabManager)
                    .tabItem {
                        Image(systemName: tabManager.selectedTab == 4 ? "person.circle.fill" : "person.circle")
                        Text("profile".localized)
                    }
                    .tag(4)
            }
            .accentColor(.musicPrimary)
        // }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
        .environmentObject(AuthenticationManager())
}
