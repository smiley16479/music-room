//
//  HomeView 2.swift
//  music-room
//
//  Created by adrien on 12/08/2025.
//


import SwiftUI

// MARK: HomeView
struct HomeView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var tabManager: MainTabManager
    @State private var recentEvents: [Event] = []
    @State private var recentPlaylists: [Playlist] = []
    @State private var invitations: [Invitation] = []
    @State private var allEvents: [Event] = []
    // Changement important : stocker l'index au lieu de l'objet
    @State private var selectedInvitationIndex: Int? = nil
    
    @State private var isLoading = false
    @State private var showCreateEvent = false
    @State private var showCreatePlaylist = false
    @State private var showAddDevice = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    WelcomeHeader2()
                    
                    if !invitations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications")
                                .font(.headline)
                                .foregroundColor(.musicPrimary)
                                .padding(.horizontal, 20)
                            
                            // Utiliser indices pour éviter les problèmes de référence
                            ForEach(Array(invitations.prefix(5).enumerated()), id: \.element.id) { index, invitation in
                                Button {
                                    print("🔵 Tapped invitation at index \(index)")
                                    selectedInvitationIndex = index
                                } label: {
                                    InvitationNotificationView2(invitation: invitation)
                                        .padding(.horizontal, 20)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    QuickActionsView2(
                        onCreateEvent: {
                            showCreateEvent = true
                            tabManager.selectedTab = 1
                        },
                        onCreatePlaylist: {
                            showCreatePlaylist = true
                            tabManager.selectedTab = 2
                        },
                        onAddDevice: {
                            showAddDevice = true
                            tabManager.selectedTab = 3
                        }
                    )
                    
                    // Reste du contenu...
                    DiscoverPlaylistsSection()
                    DiscoverEventsSection(events: allEvents)
                    Spacer()
                }
            }
            .navigationTitle("home".localized)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadInvitations()
            }
        }
        .onChange(of: authManager.isAuthenticated) { old, isAuth in
            if isAuth {
                Task { await loadInvitations() }
            }
        }
        .task {
            do {
                await loadInvitations()
                allEvents = try await APIService.shared.getEvents()
            } catch {
                print("Erreur chargement events:", error)
            }
        }
        // Sheet basée sur l'index
        .sheet(isPresented: Binding(
            get: { selectedInvitationIndex != nil },
            set: { if !$0 { selectedInvitationIndex = nil } }
        )) {
            if let index = selectedInvitationIndex,
               index < invitations.count {
                let invitation = invitations[index]
                
                InvitationDetailView2(
                    invitation: invitation,
                    onRespond: { status in
                        Task {
                            await respondToInvitation(invitation: invitation, status: status)
                            selectedInvitationIndex = nil
                        }
                    },
                    onClose: {
                        selectedInvitationIndex = nil
                    }
                )
            } else {
                Text("Erreur: Invitation non trouvée")
                    .onAppear {
                        print("❌ Index invalide ou invitations vides")
                    }
            }
        }
    }
    
    private func loadInvitations() async {
        isLoading = true
        do {
            print("🔄 Chargement des invitations...")
            let result = try await APIService.shared.getInvitations()
            
            print("✅ \(result.count) invitation(s) chargée(s)")
            
            await MainActor.run {
                self.invitations = result
                print("📝 Invitations mises à jour dans l'UI")
            }
        } catch {
            print("❌ Erreur: \(error)")
        }
        isLoading = false
    }
    
    private func respondToInvitation(invitation: Invitation, status: InvitationStatus) async {
        do {
            if status == .accepted {
                _ = try await APIService.shared.acceptInvitation(invitationId: invitation.id)
            } else if status == .declined {
                _ = try await APIService.shared.declineInvitation(invitationId: invitation.id)
            }
            await loadInvitations()
        } catch {
            print("❌ Erreur: \(error)")
        }
    }
}

// MARK: - Invitation Notification View
struct InvitationNotificationView2: View {
    let invitation: Invitation
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
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
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

// MARK: - Invitation Detail View
struct InvitationDetailView2: View {
    let invitation: Invitation
    var onRespond: ((InvitationStatus) -> Void)?
    var onClose: (() -> Void)?
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Profil de l'inviteur
                if let inviter = invitation.inviter {
                    VStack(spacing: 8) {
                        AsyncImage(url: URL(string: inviter.avatarUrl ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.musicSecondary)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        Text(inviter.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        if let email = inviter.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Type et infos liées
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: iconName(for: invitation.type))
                            .foregroundColor(.musicPrimary)
                        Text(invitation.type.localizedString)
                            .font(.headline)
                    }
                    if let msg = invitation.message, !msg.isEmpty {
                        Text(msg)
                            .font(.body)
                            .foregroundColor(.textSecondary)
                    }
                    if let event = invitation.event {
                        Divider()
                        Text("Événement: \(event.name)")
                            .font(.subheadline)
                        if let desc = event.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let playlist = invitation.playlist {
                        Divider()
                        Text("Playlist: \(playlist.name)")
                            .font(.subheadline)
                        if let desc = playlist.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if invitation.status == .pending {
                    HStack(spacing: 16) {
                        Button {
                            isProcessing = true
                            onRespond?(.accepted)
                        } label: {
                            Text("Accepter")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing)
                        Button {
                            isProcessing = true
                            onRespond?(.declined)
                        } label: {
                            Text("Refuser")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            .padding()
            .navigationTitle("Détail de la notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { onClose?() }
                }
            }
        }
    }

    private func iconName(for type: InvitationType) -> String {
        switch type {
        case .event: return "calendar.badge.plus"
        case .playlist: return "music.note.list"
        case .friend: return "person.crop.circle.badge.plus"
        }
    }
}


// MARK: - Welcome Header
struct WelcomeHeader2: View {
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
struct QuickActionsView2: View {
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
                QuickActionButton2(
                    title: "create_event".localized,
                    icon: "calendar.badge.plus",
                    color: .musicPrimary,
                    action: onCreateEvent
                )
                QuickActionButton2(
                    title: "create_playlist".localized,
                    icon: "music.note.list",
                    color: .musicSecondary,
                    action: onCreatePlaylist
                )
                QuickActionButton2(
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

struct QuickActionButton2: View {
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
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Section Header
struct SectionHeaderView2: View {
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
struct EventCardView2: View {
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
struct PlaylistCardView2: View {
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

// MARK: - Discover Playlists Section
struct DiscoverPlaylistsSection: View {
  @EnvironmentObject private var tabManager: MainTabManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("discover_playlists".localized)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 20)
            
            LazyVStack(spacing: 12) {
                // Placeholder for discover content
                ForEach(0..<3, id: \.self) { _ in
                    CardView {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Discover Playlists")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                                
                                Text("Find playlists for you")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        tabManager.selectedTab = 2
                    }
                }
            }
        }
    }
}

// MARK: - Discover Events Section
struct DiscoverEventsSection: View {
    @EnvironmentObject private var tabManager: MainTabManager
    let events: [Event]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("discover_events".localized)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 20)
            
            LazyVStack(spacing: 12) {
                ForEach(events) { event in
                    EventCardView2(event: event)
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            tabManager.selectedTab = 1
                        }
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
