import SwiftUI
import AVFoundation

// MARK: - Deezer Search View
struct DeezerSearchView: View {
    @StateObject private var deezerService = DeezerService()
    @State var playlistViewModel: PlaylistViewModel
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
//                if let error = errorMessage {
//                    Section {
//                        Text(error).foregroundColor(.red)
//                    }
//                }
                
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
                    Task{
                        await playlistViewModel.addTrackToPlaylist(track.asTrack)
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: { track in
                Text("\(track.title) par \(track.artist.name)")
            }
        }
    }
}

// MARK: - Deezer Track Row
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
            
            // Track info
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

// MARK: - Playlist Details View
struct PlaylistDetailsView: View {
    let playlist: Playlist
    @State var viewModel: PlaylistViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var displayMode: DisplayMode = .list
    @State private var showingDeezerSearch = false
    @State private var showingProposedTracks = false
    
    init(playlist: Playlist) {
        self.playlist = playlist
        // Crée une seule instance avec les bonnes données
        let vm = PlaylistViewModel(playlist: playlist)
        let playlistTracks: [Track] = (playlist.tracks ?? []).map { $0.track }
        vm.tracks.append(contentsOf: playlistTracks)
        _viewModel = State(wrappedValue: vm)
    }

    // Configuration variables
    var maxTracksToDisplay: Int = 20
    var albumArtSize: CGFloat = 180
    var carouselScrollSpeed: Double = 1.0
    var onTrackSelected: ((Track) -> Void)?
    
    enum DisplayMode {
        case list
        case carousel
    }

    // Simule si l'utilisateur est admin sur l'event (à remplacer par ta logique réelle)
    var isAdmin: Bool {
        guard let currentUser = authManager.currentUser else { return false }
        return playlist.collaborators?.contains(where: { $0.id == currentUser.id }) == true || playlist.creatorId == currentUser.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle and add button
            HStack {
                Text(playlist.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                if !viewModel.proposedTracks.isEmpty {
                    Button(action: {
                        showingProposedTracks.toggle()
                    }) {
                        Label("\(viewModel.proposedTracks.count)", systemImage: "envelope.badge")
                            .font(.callout)
                            .foregroundColor(.orange)
                    }
                }
                Button(action: {
                    showingDeezerSearch.toggle()
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.green)
                }
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

            // Audio player visible seulement pour les admins
            if isAdmin {
               AudioPlayerView(viewModel: viewModel)
            }

        /* Button("Test Socket") {
            viewModel.eventsSocket.test()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .foregroundColor(.blue) */

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
        .task {
            await viewModel.loadPlaylistDetails()
        }
        .onAppear {
            // Debug: Afficher les tracks et leur statut
            print("🎵 DEBUG: Playlist loaded with \(viewModel.tracks.count) tracks")
            for (index, track) in viewModel.tracks.enumerated() {
                print("  - Track [\(index)]: \(track.title)")
                print("    ID: \(track.id)")
                print("    isCurrentlyPlaying: \(track.isCurrentlyPlaying ?? false)")
                print("    hasPlayed: \(track.hasPlayed ?? false)")
            }
            
            // Debug: Current track ID du viewModel
            if let currentId = viewModel.currentTrackId {
                print("🎵 Current track ID in viewModel: \(currentId)")
                let currentIndex = viewModel.tracks.firstIndex { $0.id == currentId } ?? -1
                print("🎵 Current track index calculated: \(currentIndex)")
                print("🎵 viewModel.currentTrackIndex: \(viewModel.currentTrackIndex)")
            } else {
                print("🎵 No current track ID in viewModel")
            }
        }
    }
    // MARK: List View
    @ViewBuilder
    private var listView: some View {
        if isAdmin {
            adminListView
        } else {
            userScrollView
        }
    }

    private var adminListView: some View {
        List {
            ForEach(Array(viewModel.tracks.prefix(maxTracksToDisplay).enumerated()), id: \.element.id) { index, track in
                let calculatedCurrentIndex = viewModel.currentTrackId != nil ? 
                    (viewModel.tracks.firstIndex { $0.id == viewModel.currentTrackId } ?? viewModel.currentTrackIndex) : 
                    viewModel.currentTrackIndex
                
                TrackRowView(
                    track: track,
                    onLike: { viewModel.voteTrack(id: track.id, isLike: true) },
                    onDislike: { viewModel.voteTrack(id: track.id, isLike: false) },
                    canVote: !(track.hasPlayed ?? false)
                          && !((track.isCurrentlyPlaying ?? false) || (viewModel.currentTrackId == track.id))
                          && !(index < calculatedCurrentIndex)  // Pas de vote pour les tracks avant la courante
                          && (playlist.name.hasPrefix("[Event]")),
                    currentTrackId: viewModel.currentTrackId,
                    trackIndex: index,
                    currentTrackIndex: calculatedCurrentIndex
                )
                .listRowInsets(EdgeInsets())
                .contentShape(Rectangle())
                .onTapGesture {
                    // Sélectionne la track et démarre automatiquement
                    viewModel.currentTrackId = track.id
                    viewModel.togglePlayPause(for: track)
                }
            }
            .onDelete { indexSet in
                // Récupérer les tracks à supprimer AVANT de modifier le tableau
                let tracksToDelete = indexSet.map { viewModel.tracks[$0] }
                
                // Supprimer du tableau (SwiftUI s'occupe des animations)
                viewModel.tracks.remove(atOffsets: indexSet)
                
                // Supprimer de la base de données en async
                Task {
                    for track in tracksToDelete {
                        try await APIService.shared.removeMusicFromPlaylist(playlist.id, trackId: track.id)
                    }
                }
            }
            // .alert(item: $viewModel.errorMessage) { message in // alert "déjà voté msg" mais redondant avec l'autre Alert qui provoque un warning pour swift
            //     Alert(title: Text("Erreur"), message: Text(message), dismissButton: .default(Text("OK")) {
            //         viewModel.errorMessage = nil
            //     })
            // }
        }
    }

    private var userScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.tracks.prefix(maxTracksToDisplay).enumerated()), id: \.element.id) { index, track in
                    let calculatedCurrentIndex = viewModel.currentTrackId != nil ? 
                        (viewModel.tracks.firstIndex { $0.id == viewModel.currentTrackId } ?? viewModel.currentTrackIndex) : 
                        viewModel.currentTrackIndex
                    
                    TrackRowView(
                        track: track,
                        onLike: { viewModel.voteTrack(id: track.id, isLike: true) },
                        onDislike: { viewModel.voteTrack(id: track.id, isLike: false) },
                        canVote: !(track.hasPlayed ?? false)
                              && !((track.isCurrentlyPlaying ?? false) || (viewModel.currentTrackId == track.id))
                              && !(index < calculatedCurrentIndex)  // Pas de vote pour les tracks avant la courante
                              && (playlist.name.hasPrefix("[Event]")),
                        currentTrackId: viewModel.currentTrackId,
                        trackIndex: index,
                        currentTrackIndex: calculatedCurrentIndex
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: Carousel View
    private var carouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -albumArtSize * 0.2) {
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

// MARK: Audio Player View
struct AudioPlayerView: View {
    @State var viewModel: PlaylistViewModel
    // @State private var audioPlayer: AVPlayer? = nil
    // @State private var isPlaying: Bool = false
    // @State private var currentTrackIndex: Int = 0
    // @State private var volume: Float = 0.5

    var body: some View {
        VStack(spacing: 8) {
            let tracks = viewModel.tracks
            if !tracks.isEmpty {
                let track = viewModel.tracks[viewModel.currentTrackIndex]
                Text(track.title)
                    .font(.headline)
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 24) {
                    Button(action: viewModel.previousTrack) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }
                    Button(action: {
                        viewModel.togglePlayPause(for: track)
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                    Button(action: viewModel.nextTrack) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                }

                // Volume slider
               /*  HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: Binding(
                        get: { Double(viewModel.volume) },
                        set: { newValue in
                            viewModel.volume = Float(newValue)
                            viewModel.audioPlayer?.volume = viewModel.volume
                            print("📢 Volume changed to: \(viewModel.volume), AVPlayer volume: \(viewModel.audioPlayer?.volume ?? -1)")
                        }
                    ), in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                }
                .padding(.horizontal) */
            }
        }
        .padding()
        .onAppear {
            viewModel.audioPlayer?.volume = viewModel.volume
            configureAudioSession()
        }
        .onChange(of: viewModel.currentTrackId) { old, newId in
            if let id = newId, let track = viewModel.tracks.first(where: { $0.id == id }) {
                Task {
                    print("Current track changed to id: \(id), title: \(track.title)")
                    await viewModel.updateNowPlaying(trackId: id)
                }
                // nextTrack() // Ne pas utiliser nextTrack ici, car cela change l'index
                // togglePlayPause(for: track)
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("📢 Audio session configured for hardware volume control")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
}

// MARK: - Proposed Tracks View
struct ProposedTracksView: View {
    @State var viewModel: PlaylistViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.proposedTracks) { track in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(track.title)
                                .font(.headline)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await viewModel.approveProposedTrack(track)
                            }
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

// MARK: - Track Row View
struct TrackRowView: View {
    let track: Track
    let onLike: () -> Void
    let onDislike: () -> Void
    let canVote: Bool
    var currentTrackId: String? = nil  // Ajout pour la synchronisation
    var trackIndex: Int = 0  // Index de cette track dans la playlist
    var currentTrackIndex: Int = 0  // Index de la track en cours
    
    // Computed property pour déterminer si la track est en cours
    private var isCurrentlyPlaying: Bool {
        return (track.isCurrentlyPlaying ?? false) || (currentTrackId == track.id)
    }
    
    // Computed property pour déterminer si la track doit être marquée comme lue
    private var shouldShowAsPlayed: Bool {
        // Si la track a vraiment été jouée, la marquer comme lue
        if track.hasPlayed ?? false {
            return true
        }
        
        // Marquer comme lues toutes les tracks avant l'index de la track courante
        return trackIndex < currentTrackIndex
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            if let albumCoverUrl = track.albumCoverUrl, let url = URL(string: albumCoverUrl) {
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
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
             Spacer()
            
            // Status indicator
            if isCurrentlyPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.green)
            } else if shouldShowAsPlayed {
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
                        .buttonStyle(BorderlessButtonStyle())
                        Text("\((track.likes ?? 0))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    VStack(spacing: 2) {
                        Button(action: onDislike) {
                            Image(systemName: "hand.thumbsdown")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Text("\((track.dislikes ?? 0))")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
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
                .fill(isCurrentlyPlaying ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Album Art View (for carousel)
struct AlbumArtView: View {
    let track: Track
    let size: CGFloat
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if let albumCoverUrl = track.albumCoverUrl, let url = URL(string: albumCoverUrl) {
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
                    (track.isCurrentlyPlaying ?? false) ?
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
                            
                            if (track.isCurrentlyPlaying ?? false) {
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
                    .scaleEffect((track.isCurrentlyPlaying ?? false) ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: track.isCurrentlyPlaying)
                    .onTapGesture {
                        onTap()
                    }
                
                Text(track.title)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: size)
                
                Text(track.artist)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: size)
            }
        }
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistDetailsView(playlist: PlaylistViewModel.mockPlaylist)
            .previewDisplayName("PlaylistDetails")
    }
}

