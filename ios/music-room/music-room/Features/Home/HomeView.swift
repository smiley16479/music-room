import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var tabManager: MainTabManager
    @State private var recentEvents: [Event] = []
    @State private var recentPlaylists: [Playlist] = []
    @State private var invitations: [Invitation] = []
    @State private var isLoading = false
    @State private var showCreateEvent = false
    @State private var showCreatePlaylist = false
    @State private var showAddDevice = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    WelcomeHeader()
                    
                    // Notifications (Invitations)
                    if !invitations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications")
                                .font(.headline)
                                .foregroundColor(.musicPrimary)
                                .padding(.horizontal, 20)
                            ForEach(invitations.prefix(5)) { invitation in
                                InvitationNotificationView(
                                    invitation: invitation,
                                    onRespond: { status in
                                        Task {
                                            await respondToInvitation(invitation: invitation, status: status)
                                        }
                                    }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                    }


                    // Quick Actions
                    QuickActionsView(
                        onCreateEvent: { showCreateEvent = true; tabManager.selectedTab = 1 },
                        onCreatePlaylist: { showCreatePlaylist = true; tabManager.selectedTab = 2 },
                        onAddDevice: { showAddDevice = true; tabManager.selectedTab = 3 }
                    )
                    
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
        async let invitationsTask = await loadInvitations()
        // Simulate loading data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        _ = await invitationsTask
        isLoading = false
    }

    private func loadInvitations() async {
        do {
            invitations = try await APIService.shared.getInvitations()
        } catch {
            print("Failed to load invitations: \(error)")
        }
    }
    
    // Gérer la réponse à une invitation
    private func respondToInvitation(invitation: Invitation, status: InvitationStatus) async {
        do {
            if status == .accepted {
                _ = try await APIService.shared.acceptInvitation(invitationId: invitation.id)
            } else if status == .declined {
                _ = try await APIService.shared.declineInvitation(invitationId: invitation.id)
            }
            // Mettre à jour la liste locale
            await loadInvitations()
        } catch {
            print("Erreur lors de la réponse à l'invitation: \(error)")
        }
    }

// MARK: - Invitation Notification View
struct InvitationNotificationView: View {
    let invitation: Invitation
    var onRespond: ((InvitationStatus) -> Void)? = nil
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: invitation.type))
                .foregroundColor(.musicPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.type.localizedString)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(invitation.status.localizedString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let msg = invitation.message, !msg.isEmpty {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
            if invitation.status == .pending {
                HStack(spacing: 8) {
                    Button {
                        isProcessing = true
                        onRespond?(.accepted)
                    } label: {
                        Text("Accepter")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .disabled(isProcessing)
                    .fixedSize()
                    Button {
                        isProcessing = true
                        onRespond?(.declined)
                    } label: {
                        Text("Refuser")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    .disabled(isProcessing)
                    .fixedSize()
                }
            }
        }
        .padding(10)
        .background(Color.cardBackground)
        .cornerRadius(10)
    }
    private func iconName(for type: InvitationType) -> String {
        switch type {
        case .event: return "calendar.badge.plus"
        case .playlist: return "music.note.list"
        case .friend: return "person.crop.circle.badge.plus"
        }
    }
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
    var onCreateEvent: () -> Void
    var onCreatePlaylist: () -> Void
    var onAddDevice: () -> Void
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
                    color: .musicPrimary,
                    action: onCreateEvent
                )
                QuickActionButton(
                    title: "create_playlist".localized,
                    icon: "music.note.list",
                    color: .musicSecondary,
                    action: onCreatePlaylist
                )
                QuickActionButton(
                    title: "add_device".localized,
                    icon: "speaker.wave.3",
                    color: .musicBackground,
                    action: onAddDevice
                )
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
                    
                    Text("\(playlist.trackCount) tracks")
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
                ForEach(0..<3, id: \.self) { _ in
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
