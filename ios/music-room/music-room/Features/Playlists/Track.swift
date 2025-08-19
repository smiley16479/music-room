import SwiftUI
import Combine

// MARK: - Models
struct PlaylistTrack: Identifiable {
    let id = UUID()
    var title: String?
    var artist: String?
    var albumArt: String? // URL de l'image
    var duration: TimeInterval?
    var startTime: TimeInterval?
    var endTime: TimeInterval?
    var likes: Int = 0
    var dislikes: Int = 0
    var hasPlayed: Bool = false
    var isCurrentlyPlaying: Bool = false
    var deezerTrackId: String? // ID Deezer pour référence
    var preview: String? // URL de preview Deezer (30 secondes)
    
    var voteScore: Int {
        likes - dislikes
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Deezer API Models
struct DeezerSearchResponse: Codable {
    let data: [DeezerTrack]
    let total: Int
    let next: String?
}

struct DeezerTrack: Codable {
    let id: Int
    let title: String
    let duration: Int
    let preview: String
    let artist: DeezerArtist
    let album: DeezerAlbum
    
    var asTrack: PlaylistTrack {
        PlaylistTrack(
            title: title,
            artist: artist.name,
            albumArt: album.cover_medium,
            duration: TimeInterval(duration),
            deezerTrackId: String(id),
            preview: preview
        )
    }
}

struct DeezerArtist: Codable {
    let id: Int
    let name: String
}

struct DeezerAlbum: Codable {
    let id: Int
    let title: String
    let cover_small: String
    let cover_medium: String
    let cover_big: String
}

// MARK: - Deezer API Service
class DeezerService: ObservableObject {
    @Published var searchResults: [DeezerTrack] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func searchTracks(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            searchError = "Erreur d'encodage de la requête"
            isSearching = false
            return
        }
        
        // Deezer API endpoint (CORS proxy needed for web/iOS)
        // Note: En production, utilisez votre propre backend pour éviter les problèmes CORS
        let urlString = "https://api.deezer.com/search?q=\(encodedQuery)&limit=20"
        
        guard let url = URL(string: urlString) else {
            searchError = "URL invalide"
            isSearching = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: DeezerSearchResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSearching = false
                    if case .failure(let error) = completion {
                        self?.searchError = "Erreur de recherche: \(error.localizedDescription)"
                        // Utiliser des données mock en cas d'erreur (pour le développement)
                        self?.loadMockSearchResults(for: query)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.searchResults = response.data
                }
            )
            .store(in: &cancellables)
    }
    
    // Mock data pour le développement (en cas d'erreur API)
    private func loadMockSearchResults(for query: String) {
        searchResults = [
            DeezerTrack(
                id: 1,
                title: "Mock: \(query) - Song 1",
                duration: 200,
                preview: "https://example.com/preview1.mp3",
                artist: DeezerArtist(id: 1, name: "Artist 1"),
                album: DeezerAlbum(
                    id: 1,
                    title: "Album 1",
                    cover_small: "https://via.placeholder.com/56",
                    cover_medium: "https://via.placeholder.com/250",
                    cover_big: "https://via.placeholder.com/500"
                )
            ),
            DeezerTrack(
                id: 2,
                title: "Mock: \(query) - Song 2",
                duration: 180,
                preview: "https://example.com/preview2.mp3",
                artist: DeezerArtist(id: 2, name: "Artist 2"),
                album: DeezerAlbum(
                    id: 2,
                    title: "Album 2",
                    cover_small: "https://via.placeholder.com/56",
                    cover_medium: "https://via.placeholder.com/250",
                    cover_big: "https://via.placeholder.com/500"
                )
            )
        ]
    }
}

// MARK: - View Model
class PlaylistViewModel: ObservableObject {
    @Published var tracks: [PlaylistTrack] = []
    @Published var currentTrackId: UUID?
    @Published var proposedTracks: [PlaylistTrack] = [] // Tracks proposés par les utilisateurs
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        tracks = [
            PlaylistTrack(title: "Bohemian Rhapsody", artist: "Queen", albumArt: "https://via.placeholder.com/250", duration: 354, likes: 45, dislikes: 2, hasPlayed: true),
            PlaylistTrack(title: "Imagine", artist: "John Lennon", albumArt: "https://via.placeholder.com/250", duration: 183, likes: 38, dislikes: 1, hasPlayed: true),
            PlaylistTrack(title: "Hotel California", artist: "Eagles", albumArt: "https://via.placeholder.com/250", duration: 391, likes: 52, dislikes: 3, isCurrentlyPlaying: true),
            PlaylistTrack(title: "Stairway to Heaven", artist: "Led Zeppelin", albumArt: "https://via.placeholder.com/250", duration: 482, likes: 41, dislikes: 5),
            PlaylistTrack(title: "Sweet Child O' Mine", artist: "Guns N' Roses", albumArt: "https://via.placeholder.com/250", duration: 356, likes: 35, dislikes: 8),
            PlaylistTrack(title: "Billie Jean", artist: "Michael Jackson", albumArt: "https://via.placeholder.com/250", duration: 294, likes: 48, dislikes: 2),
            PlaylistTrack(title: "Smells Like Teen Spirit", artist: "Nirvana", albumArt: "https://via.placeholder.com/250", duration: 301, likes: 33, dislikes: 12),
            PlaylistTrack(title: "Wonderwall", artist: "Oasis", albumArt: "https://via.placeholder.com/250", duration: 258, likes: 29, dislikes: 15)
        ]
        
        // Set current track
        if let currentTrack = tracks.first(where: { $0.isCurrentlyPlaying }) {
            currentTrackId = currentTrack.id
        }
    }
    
    func voteTrack(id: UUID, isLike: Bool) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        
        // Only allow voting on upcoming tracks
        if !tracks[index].hasPlayed && !tracks[index].isCurrentlyPlaying {
            if isLike {
                tracks[index].likes += 1
            } else {
                tracks[index].dislikes += 1
            }
            sortUpcomingTracks()
        }
    }
    
    func addTrackToPlaylist(_ track: PlaylistTrack) {
        var newTrack = track
        newTrack.likes = 0
        newTrack.dislikes = 0
        newTrack.hasPlayed = false
        newTrack.isCurrentlyPlaying = false
        tracks.append(newTrack)
        sortUpcomingTracks()
    }
    
    func addProposedTrack(_ track: PlaylistTrack) {
        proposedTracks.append(track)
    }
    
    func approveProposedTrack(_ track: PlaylistTrack) {
        addTrackToPlaylist(track)
        proposedTracks.removeAll { $0.id == track.id }
    }
    
    func rejectProposedTrack(_ track: PlaylistTrack) {
        proposedTracks.removeAll { $0.id == track.id }
    }
    
    private func sortUpcomingTracks() {
        // Find the index of the current track
        guard let currentIndex = tracks.firstIndex(where: { $0.isCurrentlyPlaying }) else { return }
        
        // Sort only upcoming tracks by vote score
        let playedTracks = tracks[0...currentIndex]
        var upcomingTracks = Array(tracks[(currentIndex + 1)...])
        upcomingTracks.sort { $0.voteScore > $1.voteScore }
        
        // Reconstruct the playlist
        tracks = Array(playedTracks) + upcomingTracks
    }
    
    var currentTrack: PlaylistTrack? {
        tracks.first(where: { $0.id == currentTrackId })
    }
}

// MARK: - Deezer Search View
struct DeezerSearchView: View {
    @StateObject private var deezerService = DeezerService()
    @ObservedObject var playlistViewModel: PlaylistViewModel
    @State private var searchText = ""
    @State private var showingProposalConfirmation = false
    @State private var selectedTrack: DeezerTrack?
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Rechercher sur Deezer...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            deezerService.searchTracks(query: searchText)
                        }
                    
                    if deezerService.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                
                // Error message
                if let error = deezerService.searchError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Search results
                List(deezerService.searchResults, id: \.id) { deezerTrack in
                    DeezerTrackRow(
                        track: deezerTrack,
                        onAdd: {
                            selectedTrack = deezerTrack
                            showingProposalConfirmation = true
                        }
                    )
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Proposer un morceau")
            .navigationBarTitleDisplayMode(.large)
            .alert("Proposer ce morceau ?", isPresented: $showingProposalConfirmation, presenting: selectedTrack) { track in
                Button("Proposer", role: .none) {
                    playlistViewModel.addProposedTrack(track.asTrack)
                }
                Button("Ajouter directement", role: .none) {
                    playlistViewModel.addTrackToPlaylist(track.asTrack)
                }
                Button("Annuler", role: .cancel) {}
            } message: { track in
                Text("\(track.title) par \(track.artist.name)")
            }
        }
    }
}

// MARK: - Deezer PlaylistTrack Row
struct DeezerTrackRow: View {
    let track: DeezerTrack
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            AsyncImage(url: URL(string: track.album.cover_small)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                    )
            }
            .frame(width: 56, height: 56)
            .cornerRadius(8)
            
            // PlaylistTrack info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.artist.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(track.album.title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Add button
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Playlist View (Component 1)
struct PlaylistView: View {
    @StateObject private var viewModel = PlaylistViewModel()
    @State private var displayMode: DisplayMode = .list
    @State private var showingDeezerSearch = false
    @State private var showingProposedTracks = false
    
    // Configuration variables
    var maxTracksToDisplay: Int = 20
    var albumArtSize: CGFloat = 180
    var carouselScrollSpeed: Double = 1.0
    var onTrackSelected: ((PlaylistTrack) -> Void)?
    
    enum DisplayMode {
        case list
        case carousel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle and add button
            HStack {
                Text("Playlist")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Proposed tracks badge
                if !viewModel.proposedTracks.isEmpty {
                    Button(action: {
                        showingProposedTracks.toggle()
                    }) {
                        Label("\(viewModel.proposedTracks.count)", systemImage: "envelope.badge")
                            .font(.callout)
                            .foregroundColor(.orange)
                    }
                }
                
                // Add from Deezer button
                Button(action: {
                    showingDeezerSearch.toggle()
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                
                // View mode toggle
                Button(action: {
                    withAnimation(.spring()) {
                        displayMode = displayMode == .list ? .carousel : .list
                    }
                }) {
                    Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            // Content
            if displayMode == .list {
                listView
            } else {
                carouselView
            }
        }
        .sheet(isPresented: $showingDeezerSearch) {
            DeezerSearchView(playlistViewModel: viewModel)
        }
        .sheet(isPresented: $showingProposedTracks) {
            ProposedTracksView(viewModel: viewModel)
        }
    }
    
    // MARK: List View
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.tracks.prefix(maxTracksToDisplay))) { track in
                    TrackRowView(
                        track: track,
                        onLike: { viewModel.voteTrack(id: track.id, isLike: true) },
                        onDislike: { viewModel.voteTrack(id: track.id, isLike: false) },
                        canVote: !track.hasPlayed && !track.isCurrentlyPlaying
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: Carousel View
    private var carouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -albumArtSize * 0.4) {
                ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                    AlbumArtView(
                        track: track,
                        size: albumArtSize,
                        index: index,
                        onTap: {
                            onTrackSelected?(track)
                        }
                    )
                }
            }
            .padding(.horizontal, albumArtSize)
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Proposed Tracks View
struct ProposedTracksView: View {
    @ObservedObject var viewModel: PlaylistViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.proposedTracks) { track in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(track.title ?? "Unknown")
                                .font(.headline)
                            Text(track.artist ?? "Unknown Artist")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.approveProposedTrack(track)
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        
                        Button(action: {
                            viewModel.rejectProposedTrack(track)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Morceaux proposés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PlaylistTrack Row View
struct TrackRowView: View {
    let track: PlaylistTrack
    let onLike: () -> Void
    let onDislike: () -> Void
    let canVote: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            if let albumArt = track.albumArt, let url = URL(string: albumArt) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
                    .frame(width: 50, height: 50)
            }
            
            // PlaylistTrack info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title ?? "Unknown Title")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.artist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status indicator
            if track.isCurrentlyPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.green)
            } else if track.hasPlayed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.gray)
            }
            
            // Vote section
            if canVote {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Button(action: onLike) {
                            Image(systemName: "hand.thumbsup")
                                .foregroundColor(.green)
                        }
                        Text("\(track.likes)")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    VStack(spacing: 2) {
                        Button(action: onDislike) {
                            Image(systemName: "hand.thumbsdown")
                                .foregroundColor(.red)
                        }
                        Text("\(track.dislikes)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            } else {
                // Just show vote counts
                HStack(spacing: 12) {
                    Label("\(track.likes)", systemImage: "hand.thumbsup.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Label("\(track.dislikes)", systemImage: "hand.thumbsdown.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Duration
            Text(track.formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(track.isCurrentlyPlaying ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Album Art View (for carousel)
struct AlbumArtView: View {
    let track: PlaylistTrack
    let size: CGFloat
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if let albumArt = track.albumArt, let url = URL(string: albumArt) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                        )
                        .frame(width: size, height: size)
                }
                .cornerRadius(12)
                .overlay(
                    track.isCurrentlyPlaying ?
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(8)
                    : nil,
                    alignment: .topTrailing
                )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: Double(index) * 0.1, saturation: 0.6, brightness: 0.8),
                                Color(hue: Double(index) * 0.1, saturation: 0.4, brightness: 0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack {
                            Image(systemName: "music.note")
                                .font(.system(size: size * 0.3))
                                .foregroundColor(.white.opacity(0.8))
                            
                            if track.isCurrentlyPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                        }
                    )
                    .frame(width: size, height: size)
                    .rotation3DEffect(
                        .degrees(index % 2 == 0 ? -15 : 15),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: 0.5
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(track.isCurrentlyPlaying ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: track.isCurrentlyPlaying)
                    .onTapGesture {
                        onTap()
                    }
                
                Text(track.title ?? "Unknown")
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: size)
                
                Text(track.artist ?? "Unknown Artist")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: size)
            }
        }
    }
}
// MARK: - Now Playing View (Component 2)
struct NowPlayingView: View {
    @StateObject private var viewModel = PlaylistViewModel()
    
    // Configuration variables
    var showVoteButtons: Bool = true
    var artworkSize: CGFloat = 300
    var onVote: ((Bool) -> Void)?
    
    // External data injection
    var externalTrack: PlaylistTrack?
    
    private var displayTrack: PlaylistTrack? {
        externalTrack ?? viewModel.currentTrack
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Artwork
            if let albumArt = displayTrack?.albumArt, let url = URL(string: albumArt) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: artworkSize, height: artworkSize)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                        )
                        .frame(width: artworkSize, height: artworkSize)
                }
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: artworkSize * 0.4))
                            .foregroundColor(.white.opacity(0.8))
                    )
                    .frame(width: artworkSize, height: artworkSize)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            
            // PlaylistTrack info
            VStack(spacing: 8) {
                Text(displayTrack?.title ?? "No PlaylistTrack Playing")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(displayTrack?.artist ?? "Unknown Artist")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            // Duration info
            if let track = displayTrack {
                HStack {
                    Text("Duration:")
                        .foregroundColor(.secondary)
                    Text(track.formattedDuration)
                        .fontWeight(.medium)
                }
                .font(.callout)
            }
            
            // Vote buttons (if enabled and track is playing)
            if showVoteButtons, let track = displayTrack, track.isCurrentlyPlaying {
                HStack(spacing: 40) {
                    VStack {
                        Button(action: { onVote?(true) }) {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                )
                        }
                        Text("\(track.likes)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    VStack {
                        Button(action: { onVote?(false) }) {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                )
                        }
                        Text("\(track.dislikes)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Playback controls placeholder
            HStack(spacing: 30) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .disabled(true)
                
                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.largeTitle)
                        .foregroundColor(.primary)
                }
                .disabled(true)
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .disabled(true)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Queue View (Component 3)
struct QueueView: View {
    @StateObject private var viewModel = PlaylistViewModel()
    @State private var isExpanded = false
    
    // Configuration variables
    var maxTracksInCollapsed: Int = 3
    var showVoteControls: Bool = true
    var backgroundColor: Color = Color(UIColor.systemBackground)
    
    var upcomingTracks: [PlaylistTrack] {
        guard let currentIndex = viewModel.tracks.firstIndex(where: { $0.isCurrentlyPlaying }) else {
            return Array(viewModel.tracks.prefix(maxTracksInCollapsed))
        }
        return Array(viewModel.tracks.suffix(from: currentIndex + 1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("File d'attente", systemImage: "list.bullet.below.rectangle")
                    .font(.headline)
                
                Spacer()
                
                if upcomingTracks.count > maxTracksInCollapsed {
                    Button(action: {
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Réduire" : "Voir tout")
                                .font(.caption)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            // Tracks list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(upcomingTracks.prefix(isExpanded ? upcomingTracks.count : maxTracksInCollapsed).enumerated()), id: \.element.id) { index, track in
                        QueueTrackRow(
                            track: track,
                            position: index + 1,
                            showVoteControls: showVoteControls,
                            onVote: { isLike in
                                viewModel.voteTrack(id: track.id, isLike: isLike)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: isExpanded ? .infinity : nil)
            
            // Remaining tracks indicator
            if !isExpanded && upcomingTracks.count > maxTracksInCollapsed {
                Text("+ \(upcomingTracks.count - maxTracksInCollapsed) autres morceaux")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(backgroundColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Queue PlaylistTrack Row
struct QueueTrackRow: View {
    let track: PlaylistTrack
    let position: Int
    let showVoteControls: Bool
    let onVote: (Bool) -> Void
    
    @State private var hasVoted = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Position
            Text("\(position)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // Album art thumbnail
            if let albumArt = track.albumArt, let url = URL(string: albumArt) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            
            // PlaylistTrack info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(track.artist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Vote score
            if track.voteScore != 0 {
                HStack(spacing: 2) {
                    Image(systemName: track.voteScore > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text("\(abs(track.voteScore))")
                        .font(.caption)
                }
                .foregroundColor(track.voteScore > 0 ? .green : .red)
            }
            
            // Vote controls
            if showVoteControls && !hasVoted {
                HStack(spacing: 12) {
                    Button(action: {
                        onVote(true)
                        hasVoted = true
                    }) {
                        Image(systemName: "hand.thumbsup")
                            .font(.callout)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        onVote(false)
                        hasVoted = true
                    }) {
                        Image(systemName: "hand.thumbsdown")
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Duration
            Text(track.formattedDuration)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Main App View (Example Integration)
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Playlist Tab
            PlaylistView()
                .tabItem {
                    Label("Playlist", systemImage: "music.note.list")
                }
                .tag(0)
            
            // Now Playing Tab
            NowPlayingView()
                .tabItem {
                    Label("En cours", systemImage: "play.circle.fill")
                }
                .tag(1)
            
            // Queue Tab
            QueueView()
                .tabItem {
                    Label("File d'attente", systemImage: "list.bullet")
                }
                .tag(2)
        }
    }
}

// MARK: - Combined Dashboard View (All components in one screen)
struct DashboardView: View {
    @StateObject private var viewModel = PlaylistViewModel()
    @State private var showingDeezerSearch = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        // Now Playing Section
                        VStack(alignment: .leading) {
                            Text("En cours")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            if let currentTrack = viewModel.currentTrack {
                                NowPlayingCard(track: currentTrack)
                                    .padding(.horizontal)
                            } else {
                                Text("Aucun morceau en cours")
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Queue Section
                        VStack(alignment: .leading) {
                            HStack {
                                Text("File d'attente")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingDeezerSearch.toggle()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            QueueView(maxTracksInCollapsed: 5)
                                .padding(.horizontal)
                        }
                        
                        // Full Playlist
                        VStack(alignment: .leading) {
                            Text("Playlist complète")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            PlaylistView(maxTracksToDisplay: 50)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Party Playlist")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDeezerSearch) {
                DeezerSearchView(playlistViewModel: viewModel)
            }
        }
    }
}

// MARK: - Now Playing Card (Compact version for dashboard)
struct NowPlayingCard: View {
    let track: PlaylistTrack
    
    var body: some View {
        HStack(spacing: 16) {
            // Album art
            if let albumArt = track.albumArt, let url = URL(string: albumArt) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView())
                }
                .frame(width: 80, height: 80)
                .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.8))
                    )
                    .frame(width: 80, height: 80)
            }
            
            // PlaylistTrack info
            VStack(alignment: .leading, spacing: 8) {
                Text(track.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Progress bar placeholder
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * 0.3)
                                Spacer()
                            }
                        )
                }
                .frame(height: 4)
                
                // Duration and votes
                HStack {
                    Text(track.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label("\(track.likes)", systemImage: "hand.thumbsup.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Label("\(track.dislikes)", systemImage: "hand.thumbsdown.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Animated speaker icon
            Image(systemName: "speaker.wave.2.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .symbolEffect(.pulse)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
        )
    }
}
    
// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDisplayName("Tab View")
            
            DashboardView()
                .previewDisplayName("Dashboard")
            
            PlaylistView()
                .previewDisplayName("Playlist")
            
            NowPlayingView()
                .previewDisplayName("Now Playing")
            
            QueueView()
                .previewDisplayName("Queue")
        }
    }
}

