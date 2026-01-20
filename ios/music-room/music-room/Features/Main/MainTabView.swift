import SwiftUI

class MainTabManager: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var selectedPlaylist: Playlist? = nil
    @Published var selectedEvent: Event? = nil
}

struct MainTabView: View {
    @StateObject private var tabManager = MainTabManager()
    let devicesSocket = DevicesSocketService.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
        devicesSocket.prepareConnectDevice(identifier)
    }

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {
            HomeView()
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
        .onChange(of: scenePhase) { newPhase in
            let identifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
            if newPhase == .background || newPhase == .inactive {
                devicesSocket.disconnectDevice(identifier)
            } else if newPhase == .active {
                devicesSocket.prepareConnectDevice(identifier)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
        .environmentObject(AuthenticationManager())
}
