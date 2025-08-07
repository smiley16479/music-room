import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("home".localized)
                }
                .tag(0)
            
            EventsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "calendar.circle.fill" : "calendar.circle")
                    Text("events".localized)
                }
                .tag(1)
            
            PlaylistsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "music.note.list" : "music.note.list")
                    Text("playlists".localized)
                }
                .tag(2)
            
            DevicesView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "speaker.wave.3.fill" : "speaker.wave.3")
                    Text("devices".localized)
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.circle.fill" : "person.circle")
                    Text("profile".localized)
                }
                .tag(4)
        }
        .accentColor(.musicPrimary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
        .environmentObject(AuthenticationManager())
}
