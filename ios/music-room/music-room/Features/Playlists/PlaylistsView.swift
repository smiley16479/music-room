import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var tabManager: MainTabManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var playlists: [Playlist] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingCreatePlaylist = false
    @State private var selectedFilter: PlaylistFilter = .all
    @State private var selectedPlaylist: Playlist? = nil // pour la navigation automatique
    @State private var playlistToEdit: Playlist? = nil

    var filteredPlaylists: [Playlist] {
        var filtered = playlists
        
        if !searchText.isEmpty {
            filtered = filtered.filter { playlist in
                playlist.name.localizedCaseInsensitiveContains(searchText) ||
                playlist.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .myPlaylists:
            // Filter playlists created by current user
            if let currentUserId = authManager.currentUser?.id {
                filtered = filtered.filter { $0.creatorId == currentUserId }
            }
//        case .collaborative:
//            filtered = filtered.filter { $0.isCollaborative }
        case .event:
            filtered = filtered.filter { $0.name.hasPrefix("[Event]") }
        case .public:
            filtered = filtered.filter { $0.visibility == .public }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(PlaylistFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.localizedString,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.secondaryBackground)
                
                // Playlists Grid
                if isLoading {
                    LoadingView(message: "Loading playlists...")
                } else if filteredPlaylists.isEmpty {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "No Playlists Found",
                        message: searchText.isEmpty ?
                            "No playlists available. Create your first playlist!" :
                            "No playlists match your search criteria.",
                        buttonTitle: searchText.isEmpty ? "create_playlist".localized : nil,
                        buttonAction: searchText.isEmpty ? { showingCreatePlaylist = true } : nil
                    )
                } else {
                    ScrollView {
                        PlaylistsGrid(
                          playlists: filteredPlaylists,
                          playlistToEdit: $playlistToEdit
                        )
                    }
                }
            }
            .navigationTitle("playlists".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreatePlaylist = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.musicPrimary)
                    }
                }
            }
            // Navigation automatique vers PlaylistDetailsView
            .navigationDestination(isPresented: Binding(
                get: { selectedPlaylist != nil },
                set: { if !$0 { selectedPlaylist = nil } }
            )) {
                if let playlist = selectedPlaylist {
                    // Pour forcer le refresh lors de la sélection de l'event's playlist ajout de: ".id(playlist.id)"
                    PlaylistDetailsView(playlist: playlist).id(playlist.id)
                }
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView() { newPlaylist in
                playlists.append(newPlaylist)
            }
        }
        .sheet(item: $playlistToEdit) { playlist in
            EditPlaylistSheet(
                playlist: playlist,
                onDelete: { deleted in
                    playlists.removeAll { $0.id == deleted.id }
                    playlistToEdit = nil
                },
                onInvite: { invited in
                    playlistToEdit = nil
                },
                onUpdate: { updated in
                    if let idx = playlists.firstIndex(where: { $0.id == updated.id }) {
                        playlists[idx] = updated
                    }
                    playlistToEdit = nil
                }
            )
        }
        .task {
            await loadPlaylists()
        }
        .refreshable {
            await loadPlaylists()
        }
        // .sheet(item: $selectedPlaylist) { playlist in
        //     PlaylistDetailsView(playlist: playlist)
        // }
        .onAppear {
            if let playlist = tabManager.selectedPlaylist {
                selectedPlaylist = playlist
                tabManager.selectedPlaylist = nil
            }
            // if let playlist = tabManager.selectedPlaylist {
            //     // Navigation automatique vers la playlist sélectionnée
            //     // Par exemple :
            //     DispatchQueue.main.async {
            //         // Ouvre la vue de détails
            //         // (à adapter selon ta logique, ex: navigation ou sheet)
            //     }
            //     tabManager.selectedPlaylist = nil // Reset après navigation
            // }
        }
    }
    
    private func loadPlaylists() async {
        isLoading = true
        
        do {
            playlists = try await APIService.shared.getPlaylists()
        } catch {
            print("Failed to load playlists: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Playlist Filter
enum PlaylistFilter: CaseIterable {
    case all, myPlaylists, event, `public`
    
    var localizedString: String {
        switch self {
        case .all:
            return "All"
        case .myPlaylists:
            return "My Playlists"
        case .event:
            return "event".localized
        case .public:
            return "public".localized
        }
    }
}

// MARK: - Playlist Grid
struct PlaylistsGrid: View {
    let playlists: [Playlist]
    @Binding var playlistToEdit: Playlist?
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 20) {
            ForEach(playlists) { playlist in
                ZStack(alignment: .topTrailing) {
                    NavigationLink(
                        destination: PlaylistDetailsView(playlist: playlist),
                        label: {
                            PlaylistGridItem(playlist: playlist)
                        }
                    )
                    Button(action: {
                        playlistToEdit = playlist
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.musicPrimary)
                            .padding(8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)

    }
}

// MARK: - Playlist Grid Item
struct PlaylistGridItem: View {
    let playlist: Playlist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover Image
            AsyncImage(url: URL(string: playlist.coverImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.musicBackground.opacity(0.6),
                                Color.musicSecondary.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack {
                            Image(systemName: "music.note")
                                .font(.system(size: 30))
                                .foregroundColor(.musicPrimary)
                            
                            Text(String(playlist.name.prefix(2)).uppercased())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.musicPrimary)
                        }
                    )
            }
            .frame(height: 140)
            .clipped()
            .cornerRadius(12)
            /* .overlay(
                Group {
                // Collaborative indicator
                    if playlist.isCollaborative {
                        HStack {
                            Spacer()
                            VStack {
                                Image(systemName: "person.2.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.musicPrimary)
                                    .clipShape(Circle())
                                Spacer()
                            }
                        }
                        .padding(8)
                    }
                }
            ) */
            
            // Playlist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 36, alignment: .topLeading) // Ajuste 36 selon ta police
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Label("\(playlist.trackCount)", systemImage: "music.note")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    if playlist.visibility == .public {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.musicSecondary)
                    } else {
                        Image(systemName: "lock")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                if let duration = playlist.formattedDuration {
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(8)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .frame(minHeight: 180)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Create Playlist
struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    var onPlaylistCreated: ((Playlist) -> Void)? = nil
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPublic: Bool = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Playlist Info")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                Section(header: Text("Options")) {
                    Toggle(isOn: $isPublic) {
                        Text("Public Playlist")
                    }
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("create_playlist".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlaylist()
                    }
                    .disabled(isSaving || name.isEmpty)
                }
            }
        }
    }

    private func savePlaylist() {
        isSaving = true
        errorMessage = nil
        let playlistData: [String: Any] = [
            "name": name,
            "description": description,
            "visibility": isPublic ? "public" : "private",
//            "licenseType": 
        ]
        Task {
            do {
                let createdPlaylist = try await APIService.shared.createPlaylist(playlistData)
                await MainActor.run {
                    onPlaylistCreated?(createdPlaylist)
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Edit Playlist Sheet
struct PlaylistInviteView: View {
    @Environment(\.dismiss) private var dismiss
    
    let playlist: Playlist?
    
    @State private var friends: [User] = []
    @State private var selectedFriends: Set<String> = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    init(playlist: Playlist? = nil) {
        self.playlist = playlist
    }
    
    var body: some View {
        NavigationView {
            VStack {
                inviteFriendsView
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendInvitations()
                    }
                    .disabled(selectedFriends.isEmpty || isLoading)
                }
            }
        }
        .onAppear {
            loadFriends()
        }
        .toast(message: toastMessage, isShowing: $showToast, duration: 2.0)
    }
    
    // MARK: - Invite Friends View
    private var inviteFriendsView: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView("Loading friends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if friends.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No friends found")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Friends") {
                        ForEach(filteredFriends, id: \.id) { friend in
                            FriendRowView(
                                user: friend,
                                isSelected: selectedFriends.contains(friend.id)
                            ) {
                                toggleSelection(for: friend)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private var filteredFriends: [User] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchText) ||
            (user.email?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    // MARK: - Actions
    private func loadFriends() {
        isLoading = true
        Task {
            do {
                let loadedFriends = try await APIService.shared.getUserFriends()
                await MainActor.run {
                    friends = loadedFriends.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    toastMessage = "Failed to load friends"
                    showToast = true
                }
            }
        }
    }
    
    private func toggleSelection(for user: User) {
        if selectedFriends.contains(user.id) {
            selectedFriends.remove(user.id)
        } else {
            selectedFriends.insert(user.id)
        }
    }
    
    private func sendInvitations() {
        guard let playlist = playlist else { return }
        
        isLoading = true
        Task {
            do {
                for friendId in selectedFriends {
                    try await APIService.shared.inviteUserToPlaylist(
                        playlistId: playlist.id,
                        userId: friendId,
                        message: nil
                    )
                }
                
                await MainActor.run {
                    isLoading = false
                    let count = selectedFriends.count
                    toastMessage = "Sent \(count) invitation\(count == 1 ? "" : "s")"
                    showToast = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    toastMessage = "Failed to send invitations"
                    showToast = true
                }
            }
        }
    }
}

struct EditPlaylistSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showingInviteView = false
    var playlist: Playlist
    var onDelete: (Playlist) -> Void
    var onInvite: (Playlist) -> Void
    var onUpdate: (Playlist) -> Void

    init(
        playlist: Playlist,
        onDelete: @escaping (Playlist) -> Void,
        onInvite: @escaping (Playlist) -> Void,
        onUpdate: @escaping (Playlist) -> Void
    ) {
        self.playlist = playlist
        self.onDelete = onDelete
        self.onInvite = onInvite
        self.onUpdate = onUpdate
        _name = State(initialValue: playlist.name)
        _description = State(initialValue: playlist.description ?? "")
        _isPublic = State(initialValue: playlist.visibility == .public)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Playlist")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Toggle(isOn: $isPublic) {
                        Text("Public Playlist")
                    }
                }
                Section {
                    Button("Invite Friends") {
                        showingInviteView = true
                    }
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                Section {
                    Button("Delete Playlist", role: .destructive) {
                        isDeleting = true
                        Task {
                            do {
                                try await APIService.shared.deletePlaylist(playlist.id)
                                onDelete(playlist)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                isDeleting = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        isSaving = true
                        errorMessage = nil
                        let updated = Playlist(id: playlist.id, name: name, description: description, visibility: isPublic ? .public : .private, coverImageUrl: playlist.coverImageUrl, trackCount: playlist.trackCount)
                        let updateData: [String: Any] = [
                            "name": name,
                            "description": description ?? "",
                            "visibility": isPublic ? "public" : "private",
                        ]
                        // if let url = coverImageUrl, !url.isEmpty {
                        //     updateData["coverImageUrl"] = url
                        // }
                        Task {
                            do {
                                _ = try await APIService.shared.updatePlaylist(playlist.id, updateData)
                                onUpdate(updated)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                isSaving = false
                            }
                        }
                    }
                    .disabled(isSaving || name.isEmpty)
                }
            }
            // Les champs sont initialisés via l'init personnalisé, donc plus besoin de onAppear/onChange
        }
        .sheet(isPresented: $showingInviteView) {
            PlaylistInviteView(playlist: playlist)
        }
    }
}

struct FriendRowView: View {
    let user: User
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.musicSecondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.subheadline)
                        .foregroundColor(.textPrimary)
                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .musicPrimary : .textSecondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlaylistsView()
        .environmentObject(MainTabManager())
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
