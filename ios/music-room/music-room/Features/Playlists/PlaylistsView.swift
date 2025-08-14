import SwiftUI

struct PlaylistsView: View {
    @State private var playlists: [Playlist] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingCreatePlaylist = false
    @State private var selectedFilter: PlaylistFilter = .all
    
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
        case .collaborative:
            filtered = filtered.filter { $0.isCollaborative }
        case .public:
            filtered = filtered.filter { $0.visibility == .public }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
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
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(filteredPlaylists) { playlist in
                                PlaylistGridItem(playlist: playlist)
                            }
                        }
                        .padding(20)
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
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView()
        }
        .task {
            await loadPlaylists()
        }
        .refreshable {
            await loadPlaylists()
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
    case all, myPlaylists, collaborative, `public`
    
    var localizedString: String {
        switch self {
        case .all:
            return "All"
        case .myPlaylists:
            return "My Playlists"
        case .collaborative:
            return "collaborative".localized
        case .public:
            return "public".localized
        }
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
            .overlay(
                // Collaborative indicator
                Group {
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
            )
            
            // Playlist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                
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
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Create Playlist View (Form)
struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isCollaborative: Bool = false
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
                    Toggle(isOn: $isCollaborative) {
                        Text("Collaborative")
                    }
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
            "isCollaborative": isCollaborative,
            "visibility": isPublic ? "public" : "private"
        ]
        Task {
            do {
                _ = try await APIService.shared.createPlaylist(playlistData)
                await MainActor.run {
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

#Preview {
    PlaylistsView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager())
}
