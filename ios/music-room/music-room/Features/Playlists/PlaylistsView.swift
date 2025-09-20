import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var tabManager: MainTabManager
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
            break
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
                /* NavigationLink(
                    destination: PlaylistDetailsView(playlist: playlist),
                    label: {
                        PlaylistGridItem(playlist: playlist)
                    }
                )*/
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
struct EditPlaylistSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
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
                        onInvite(playlist)
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
    }
}

#Preview {
    PlaylistsView()
        .environmentObject(MainTabManager())
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
