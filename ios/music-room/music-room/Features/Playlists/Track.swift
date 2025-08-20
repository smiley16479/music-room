import SwiftUI
import Combine
import AVFoundation

// MARK: - View Model
@Observable
class PlaylistViewModel: ObservableObject {
    var playlist: Playlist
    var tracks: [Track] = []
    var currentTrackId: String?
    var proposedTracks: [Track] = [] // Tracks proposés par les utilisateurs
//    @State private var errorMessage: String?
    
    init(playlist: Playlist) {
        self.playlist = playlist
        loadMockData()
    }

    static var mockPlaylist: Playlist {
        Playlist(
            id: UUID().uuidString,
            name: "Mock Playlist",
            description: "Playlist de test",
            tracks: [
                PlaylistTrack(
                    id: UUID().uuidString,
                    track: Track(id: UUID().uuidString, title: "Mock Song 1", artist: "Mock Artist", duration: 180),
                    addedBy: User.mock()
                ),
                PlaylistTrack(
                    id: UUID().uuidString,
                    track: Track(id: UUID().uuidString, title: "Mock Song 2", artist: "Mock Artist", duration: 200),
                    addedBy: User.mock()
                )
            ]
        )
    }
    
    func loadMockData() {
        tracks = [
            // Track(id: UUID().uuidString ,title: "Bohemian Rhapsody", artist: "Queen", duration: 354, albumCoverUrl: "https://cdn-images.dzcdn.net/images/cover/90192223423fbfa45bbf4ef9f68cf9f7/250x250-000000-80-0-0.jpg", likes: 45, dislikes: 2, hasPlayed: true),
            // Track(id: UUID().uuidString ,title: "Imagine", artist: "John Lennon", duration: 183, albumCoverUrl: "https://cdn-images.dzcdn.net/images/cover/2675a9277dfabb74c32b7a3b2c9b0170/250x250-000000-80-0-0.jpg", likes: 38, dislikes: 1, hasPlayed: true),
            // Track(id: UUID().uuidString ,title: "Hotel California", artist: "Eagles", duration: 391, albumCoverUrl: "https://cdn-images.dzcdn.net/images/cover/7a6c7b49cfdaf4ee233f66c3070d2f40/250x250-000000-80-0-0.jpg", likes: 52, dislikes: 3, isCurrentlyPlaying: true),
            // Track(id: UUID().uuidString ,title: "Stairway to Heaven", artist: "Led Zeppelin", duration: 482,
            //       previewUrl: "https://cdnt-preview.dzcdn.net/api/1/1/0/9/2/0/092937978412c7b50c249d0e3664e009.mp3?hdnea=exp=1755637822~acl=/api/1/1/0/9/2/0/092937978412c7b50c249d0e3664e009.mp3*~data=user_id=0,application_id=42~hmac=26afacddc0d42b108305ce2c13ea60a8c1a80b9af460d52344ed6b58d22488c8",
            //       albumCoverUrl: "https://cdn-images.dzcdn.net/images/cover/460a0edd96f743be03b7405eac38c633/250x250-000000-80-0-0.jpg",
            //       likes: 41, dislikes: 5),
            // Track(id: UUID().uuidString ,title: "Sweet Child O' Mine", artist: "Guns N' Roses", duration: 356, albumCoverUrl: "https://cdn-images.dzcdn.net/images/cover/8bfe7b3b0985d9ff0751090fb2b6f73f/250x250-000000-80-0-0.jpg", likes: 35, dislikes: 8),
            // Track(id: UUID().uuidString ,title: "Billie Jean", artist: "Michael Jackson", duration: 294, albumCoverUrl: "https://via.placeholder.com/250", likes: 48, dislikes: 2),
            // Track(id: UUID().uuidString ,title: "Smells Like Teen Spirit", artist: "Nirvana", duration: 301, albumCoverUrl: "https://via.placeholder.com/250", likes: 33, dislikes: 12),
            // Track(id: UUID().uuidString ,title: "Wonderwall", artist: "Oasis", duration: 258, albumCoverUrl: "https://via.placeholder.com/250", likes: 29, dislikes: 15)
        ]
        
        // Set current track
        if let currentTrack = tracks.first(where: { ($0.isCurrentlyPlaying ?? false) }) {
            currentTrackId = currentTrack.id
        }
    }

    func loadPlaylistDetails() async {
        // Appelle l’API pour récupérer les détails et les tracks
        do {
            let playlistTracks = try await APIService.shared.getPlaylistTracks(playlist.id).map { $0.track }
            // Mets à jour les tracks et autres infos
            self.tracks = playlistTracks
            // ... autres mises à jour ...
        } catch {
            // Gère l’erreur
        }
    }
    
    func voteTrack(id: String, isLike: Bool) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        
        // Only allow voting on upcoming tracks
        if !(tracks[index].hasPlayed ?? false) && !(tracks[index].isCurrentlyPlaying ?? false) {
            if isLike {
                tracks[index].likes = (tracks[index].likes ?? 0) + 1
            } else {
                tracks[index].dislikes = (tracks[index].dislikes ?? 0) + 1
            }
            sortUpcomingTracks()
        }

      // Non envoyé par http:
      // EventsSocketService.shared.emit("vote-track", [
      //   "eventId": myEventId,
      //   "trackId": id,
      //   "type": isLike ? "like" : "dislike"
      // ])
    }
    
    func addTrackToPlaylist(_ track: Track) async {
      print("Adding track to playlist: \(track)")
        var newTrack = track
        newTrack.likes = 0
        newTrack.dislikes = 0
        newTrack.hasPlayed = false
        newTrack.isCurrentlyPlaying = false
        tracks.append(newTrack)
        sortUpcomingTracks()

      let payload: [String: Any] = [
          "deezerId": track.deezerId ?? "",
          "title": track.title,
          "artist": track.artist,
          "album": track.album ?? "",
          "albumCoverUrl": track.albumCoverUrl ?? "",
          "previewUrl": track.previewUrl ?? "",
          "duration": track.duration,
          // "position": ... // optionnel si tu veux gérer la position
      ]

      Task {
          do {
              _ = try await APIService.shared.addMusicToPlaylist(playlist.id, payload)
              await MainActor.run {
//                  isSaving = false
//                  dismiss()
              }
          } catch {
              await MainActor.run {
//                    errorMessage = error.localizedDescription
//                    isSaving = false
                }
          }
      }
        // Forme du dto:
        // trackId: string
        // position?: number
    }
    
    func addProposedTrack(_ track: Track) {
        proposedTracks.append(track)
    }
    
    func approveProposedTrack(_ track: Track) async {
        await addTrackToPlaylist(track)
        proposedTracks.removeAll { $0.id == track.id }
    }
    
    func rejectProposedTrack(_ track: Track) {
        proposedTracks.removeAll { $0.id == track.id }
    }
    
    private func sortUpcomingTracks() {
        // Find the index of the current track
        guard let currentIndex = tracks.firstIndex(where: { ($0.isCurrentlyPlaying ?? false) }) else { return }
        
        // Sort only upcoming tracks by vote score
        let playedTracks = tracks[0...currentIndex]
        var upcomingTracks = Array(tracks[(currentIndex + 1)...])
        upcomingTracks.sort { $0.voteScore > $1.voteScore }
        
        // Reconstruct the playlist
        tracks = Array(playedTracks) + upcomingTracks
    }
    
    var currentTrack: Track? {
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
    @StateObject private var viewModel: PlaylistViewModel
    @State private var displayMode: DisplayMode = .list
    @State private var showingDeezerSearch = false
    @State private var showingProposedTracks = false
    
    init(playlist: Playlist) {
        self.playlist = playlist
        // Crée une seule instance avec les bonnes données
        let vm = PlaylistViewModel(playlist: playlist)
        let playlistTracks: [Track] = (playlist.tracks ?? []).map { $0.track }
        vm.tracks.append(contentsOf: playlistTracks)
        _viewModel = StateObject(wrappedValue: vm)
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
        // Remplace par ta logique d'authentification/permission
        true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle and add button
            HStack {
                Text("Playlist")
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
                        canVote: !(track.hasPlayed ?? false) && !(track.isCurrentlyPlaying ?? false)
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
    @ObservedObject var viewModel: PlaylistViewModel
    @State private var audioPlayer: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTrackIndex: Int = 0
    @State private var volume: Float = 0.5

   
   var body: some View {
       VStack(spacing: 8) {
           let tracks = viewModel.tracks
           if !tracks.isEmpty {
               let track = tracks[currentTrackIndex]
               Text(track.title)
                   .font(.headline)
               Text(track.artist)
                   .font(.caption)
                   .foregroundColor(.secondary)
               HStack(spacing: 24) {
                   Button(action: previousTrack) {
                       Image(systemName: "backward.fill")
                           .font(.title)
                   }
                   Button(action: {
                       togglePlayPause(for: track)
                   }) {
                       Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                           .font(.system(size: 44))
                           .foregroundColor(.blue)
                   }
                   Button(action: nextTrack) {
                       Image(systemName: "forward.fill")
                           .font(.title)
                   }
               }

               // Volume slider
               HStack {
                   Image(systemName: "speaker.fill")
                   Slider(value: Binding(
                       get: { Double(volume) },
                       set: { newValue in
                           volume = Float(newValue)
                           audioPlayer?.volume = volume
                       }
                   ), in: 0...1)
                   Image(systemName: "speaker.wave.3.fill")
               }
               .padding(.horizontal)
           }
       }
       .padding()
       .onAppear {
           audioPlayer?.volume = volume
       }
   }

  //  private func togglePlayPause(for track: Track) {
  //      guard let previewUrl = track.preview ?? track.previewUrl, let url = URL(string: previewUrl) else { return }
  //      if audioPlayer == nil || audioPlayer?.currentItem?.asset as? AVURLAsset != AVURLAsset(url: url) {
  //          audioPlayer = AVPlayer(url: url)
  //      }
  //      if isPlaying {
  //          audioPlayer?.pause()
  //          isPlaying = false
  //      } else {
  //          audioPlayer?.play()
  //          isPlaying = true
  //      }
  //  }

   private func togglePlayPause(for track: Track) {
    guard let previewUrl = track.preview ?? track.previewUrl, let url = URL(string: previewUrl) else { return }
    // Synchronize track state
    syncCurrentTrack(track: track)

    // Vérifie si le player joue déjà ce morceau
//    let urlTest = "https://audiocdn.epidemicsound.com/lqmp3/01K1WWG258YTCAZJMGZH0KXSYY.mp3"

    if let currentAsset = audioPlayer?.currentItem?.asset as? AVURLAsset,
       currentAsset.url == url {
        // Même morceau : toggle play/pause
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    } else {
        // Nouveau morceau : crée un nouveau player et joue
        audioPlayer = AVPlayer(url: url)
        audioPlayer?.play()
        isPlaying = true
    }
}

   private func nextTrack() {
       let tracks = viewModel.tracks
       guard !tracks.isEmpty else { return }
       // Mark previous track as played
       if tracks.indices.contains(currentTrackIndex) {
           viewModel.tracks[currentTrackIndex].hasPlayed = true
           viewModel.tracks[currentTrackIndex].isCurrentlyPlaying = false
       }
       currentTrackIndex = (currentTrackIndex + 1) % tracks.count
       isPlaying = false
       let track = tracks[currentTrackIndex]
       togglePlayPause(for: track)
   }

   private func previousTrack() {
       let tracks = viewModel.tracks
       guard !tracks.isEmpty else { return }
       // Unmark hasPlayed for current track if going back
       if tracks.indices.contains(currentTrackIndex) {
           viewModel.tracks[currentTrackIndex].hasPlayed = false
           viewModel.tracks[currentTrackIndex].isCurrentlyPlaying = false
       }
       currentTrackIndex = (currentTrackIndex - 1 + tracks.count) % tracks.count
       isPlaying = false
       let track = tracks[currentTrackIndex]
       togglePlayPause(for: track)
   }

   private func syncCurrentTrack(track: Track) {
       let tracks = viewModel.tracks
        // Update currentTrackId in the viewModel
        viewModel.currentTrackId = track.id
        
        // Update isCurrentlyPlaying for all tracks
        for i in tracks.indices {
            viewModel.tracks[i].isCurrentlyPlaying = (tracks[i].id == track.id)
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
            if (track.isCurrentlyPlaying ?? false) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.green)
            } else if (track.hasPlayed ?? false) {
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
                        Text("\((track.likes ?? 0))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    VStack(spacing: 2) {
                        Button(action: onDislike) {
                            Image(systemName: "hand.thumbsdown")
                                .foregroundColor(.red)
                        }
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
                .fill((track.isCurrentlyPlaying ?? false) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
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

