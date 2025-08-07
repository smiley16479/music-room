import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var recentEvents: [Event] = []
    @State private var recentPlaylists: [Playlist] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    WelcomeHeader()
                    
                    // Quick Actions
                    QuickActionsView()
                    
                    // Recent Events
                    if !recentEvents.isEmpty {
                        SectionHeaderView(
                            title: "recent_activity".localized,
                            actionTitle: "See All",
                            action: { /* Navigate to events */ }
                        )
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentEvents) { event in
                                    EventCardView(event: event)
                                        .frame(width: 280)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Your Playlists
                    if !recentPlaylists.isEmpty {
                        SectionHeaderView(
                            title: "your_playlists".localized,
                            actionTitle: "See All",
                            action: { /* Navigate to playlists */ }
                        )
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentPlaylists) { playlist in
                                    PlaylistCardView(playlist: playlist)
                                        .frame(width: 200)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Discover Section
                    DiscoverSection()
                    
                    Spacer()
                }
            }
            .navigationTitle("home".localized)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        // Simulate loading data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isLoading = false
    }
}

// MARK: - Welcome Header
struct WelcomeHeader: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    Text(authManager.currentUser?.displayName ?? "User")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                // Profile Picture
                AsyncImage(url: URL(string: authManager.currentUser?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.musicSecondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            .padding(.horizontal, 20)
            
            // Musical greeting animation
            MusicNotesIcon()
                .frame(width: 60, height: 60)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.musicBackground.opacity(0.3),
                    Color.musicSecondary.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    title: "create_event".localized,
                    icon: "calendar.badge.plus",
                    color: .musicPrimary
                ) {
                    // Navigate to create event
                }
                
                QuickActionButton(
                    title: "create_playlist".localized,
                    icon: "music.note.list",
                    color: .musicSecondary
                ) {
                    // Navigate to create playlist
                }
                
                QuickActionButton(
                    title: "search_music".localized,
                    icon: "magnifyingglass",
                    color: .musicBackground
                ) {
                    // Navigate to music search
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.subheadline)
                    .foregroundColor(.musicPrimary)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Event Card View
struct EventCardView: View {
    let event: Event
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        
                        if let locationName = event.locationName {
                            Text(locationName)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: event.visibility == .public ? "globe" : "lock")
                        .foregroundColor(.musicSecondary)
                }
                
                if let description = event.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(event.status.localizedString)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.musicPrimary.opacity(0.2))
                        .foregroundColor(.musicPrimary)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("participants_count".localized)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

// MARK: - Playlist Card View
struct PlaylistCardView: View {
    let playlist: Playlist
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: playlist.coverImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.musicBackground.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.musicPrimary)
                        )
                }
                .frame(height: 100)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text("\\(playlist.trackCount) tracks")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

// MARK: - Discover Section
struct DiscoverSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("discover_events".localized)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 20)
            
            LazyVStack(spacing: 12) {
                // Placeholder for discover content
                ForEach(0..<3, id: \\.self) { _ in
                    CardView {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Discover Music Events")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                                
                                Text("Find events near you")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
        .environmentObject(AuthenticationManager())
}
