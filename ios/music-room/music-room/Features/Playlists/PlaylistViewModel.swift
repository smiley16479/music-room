//
//  PlaylistViewModel.swift
//  music-room
//
//  Created by adrien on 15/09/2025.
//

import Combine
import AVFoundation

// MARK: - View Model
@Observable
class PlaylistViewModel {
    var playlist: Playlist
    var tracks: [Track] = []
    var currentTrackId: String?
    var proposedTracks: [Track] = [] // Tracks proposés par les utilisateurs
    var users: [User] = [] // Utilisateurs connectés à l'événement/playlist
    var messages: [EventMessage] = [] // Messages de l'event
    var errorMessage: String?
    var currentEvent: Event? // Event associé à la playlist
    private let eventId: String?
    // @State private var errorMessage: String?
    // private let socketService = SocketService.shared
    let eventsSocket = EventsSocketService.shared
    let devicesSocket = DevicesSocketService.shared

    // Player
    var audioPlayer: AVPlayer? = nil
    var isPlaying: Bool = false
    var currentTrackIndex: Int = 0
    var volume: Float = 0.5
    
    init(playlist: Playlist) {
        self.playlist = playlist
        self.eventId = playlist.eventId
        loadMockData()
        guard let eventId = playlist.eventId else {
            print("❌ Erreur: Aucun eventId associé à cette playlist")
            return
        }

        setupSocketListeners()
    }
    
    deinit {
      guard let eventId = self.eventId else { return }
      self.eventsSocket.leaveEvent(eventId: eventId)
      // self.eventsSocket.removeAllListeners()
      // self.eventsSocket.disconnect()
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
        // Appelle l'API pour récupérer les détails et les tracks
        do {
            let playlistTracks = try await APIService.shared.getPlaylistTracks(playlist.id).map { $0.track }
            
            // Si cette playlist est associée à un event, récupérer le currentTrackId
            if let eventId = playlist.eventId {
                let event = try await APIService.shared.getEvent(eventId: eventId)
                print("🎵 Event loaded - currentTrackId: \(event.currentTrackId ?? "nil")")
                await MainActor.run {
                    self.currentTrackId = event.currentTrackId
                    if let currentId = event.currentTrackId {
                        // Trouver l'index de la track courante
                        self.currentTrackIndex = playlistTracks.firstIndex { $0.id == currentId } ?? 0
                        print("🎵 Set currentTrackIndex to: \(self.currentTrackIndex)")
                    }
                }
            }
            
            // Mets à jour les tracks et autres infos
            await MainActor.run {
                self.tracks = playlistTracks
                print("sortUpcomingTracks called, tracks count: \(tracks.count)")
                print("tracks before sort:", self.tracks.map { $0.title })
                sortUpcomingTracks()
                print("tracks after sort:", self.tracks.map { $0.title })
            }

            // 🔍 LOGS DE DEBUG : //
            if let data = try? JSONEncoder().encode(playlistTracks),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8) {
                print("✅ Response playlistTracks body:\n\(prettyString)")
            } else {
                print("⚠️ Response playlistTracks body: No data")
            }
            // 🔍 LOGS DE DEBUG : \\

        } catch {
            print("Erreur lors de la récupération des tracks: \(error)")
            await MainActor.run {
                self.errorMessage = "Vous avez déjà voté pour cette piste."
            }
        }
    }
    
    // MARK: - Voting
    func voteTrack(id: String, isLike: Bool) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        
        
        guard let eventId = playlist.eventId else {
            print("Erreur: Aucun eventId associé à cette playlist")
            return
        }
        print("Avant vote - likes: \(tracks[index].likes ?? 0), dislikes: \(tracks[index].dislikes ?? 0)")

        // Use new API service to vote
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let voteType: VoteResult.VoteType = isLike ? .like : .dislike
                let voteResult = try await APIService.shared.voteForTrack(eventId: eventId, trackId: id, voteType: voteType.rawValue)
                print("Vote enregistré: \(voteResult)")
                // Le socket mettra à jour automatiquement la vue
            } catch {
                print("Erreur lors du vote: \(error)")
                await MainActor.run {
                    self.errorMessage = "Vous avez déjà voté pour cette piste."
                }
            }
        }
    }
    
    // MARK: - Track Suggestions
    func suggestTrack(trackData: SuggestedTrackData) async {
        do {
            guard let eventId = playlist.eventId else {
                print("Erreur: Aucun eventId associé à cette playlist")
                return
            }
            let suggestion = try await APIService.shared.suggestTrack(eventId: eventId, trackData: trackData)
            print("Track suggérée: \(suggestion)")
        } catch {
            print("Erreur lors de la suggestion: \(error)")
        }
    }
    
    func approveTrackSuggestion(suggestionId: String) async {
        do {
            guard let eventId = playlist.eventId else {
                print("Erreur: Aucun eventId associé à cette playlist")
                return
            }
            let result = try await APIService.shared.approveTrackSuggestion(eventId: eventId, suggestionId: suggestionId)
            print("Suggestion approuvée: \(result)")
        } catch {
            print("Erreur lors de l'approbation: \(error)")
        }
    }
    
    func rejectTrackSuggestion(suggestionId: String) async {
        do {
            guard let eventId = playlist.eventId else {
                print("Erreur: Aucun eventId associé à cette playlist")
                return
            }
            let result = try await APIService.shared.rejectTrackSuggestion(eventId: eventId, suggestionId: suggestionId)
            print("Suggestion rejetée: \(result)")
        } catch {
            print("Erreur lors du rejet: \(error)")
        }
    }
    
    // MARK: - Playback Control
    func updateNowPlaying(trackId: String, position: Double? = nil) async {
        do {
            guard let eventId = self.eventId else {
                print("❌ Erreur: Aucun eventId associé")
                return
            }
            let result = try await APIService.shared.updateNowPlaying(eventId: eventId, trackId: trackId)
            print("Now playing mis à jour: \(result)")
        } catch {
            print("Erreur lors de la mise à jour (updateNowPlaying): \(error)")
        }
    }
    
    func skipTrack() async {
        do {
            let result = try await APIService.shared.skipTrack(eventId: playlist.id)
            print("Track skippée: \(result)")
        } catch {
            print("Erreur lors du skip: \(error)")
        }
    }
    
    func updatePlaybackState(isPlaying: Bool, position: Double? = nil) async {
        do {
            guard let eventId = self.eventId else {
                print("❌ Erreur: Aucun eventId associé")
                return
            }
            let result = try await APIService.shared.updatePlaybackState(eventId: eventId, isPlaying: isPlaying, position: position)
            print("État de lecture mis à jour: \(result)")
        } catch {
            print("Erreur lors de la mise à jour (updatePlaybackState): \(error)")
        }
    }
    
    func addTrackToPlaylist(_ track: Track) async {
      print("Adding track to playlist: \(track)")
      // let newTrack = Track(from: track) else { return }
        var newTrack = track
        newTrack.likes = 0
        newTrack.dislikes = 0
        newTrack.hasPlayed = false
        newTrack.isCurrentlyPlaying = false
        // tracks.append(newTrack)
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

      do {
          let playListTrack = try await APIService.shared.addMusicToPlaylist(playlist.id, payload)
      } catch {
        print("Erreur lors de addTrackToPlaylist: \(error)")
          // await MainActor.run {
          //    errorMessage = error.localizedDescription
          //    isSaving = false
            // }
      }
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
        if let currentIndex = tracks.firstIndex(where: { ($0.isCurrentlyPlaying ?? false) }) {
            // Sort only upcoming tracks by vote score
            let playedTracks = tracks[0...currentIndex]
            var upcomingTracks = Array(tracks[(currentIndex + 1)...])

            print("playedTracks:", playedTracks.map { $0.title })
            print("upcomingTracks before sort:", upcomingTracks.map { $0.title })

            upcomingTracks.sort { $0.voteScore > $1.voteScore }
            
            // Reconstruct the playlist
            tracks = Array(playedTracks) + upcomingTracks

            print("tracks after sorting: \(tracks.map { $0.voteScore })")
        } else {
          tracks.sort { $0.voteScore > $1.voteScore }
          return 
        }
    }
    
    var currentTrack: Track? {
        tracks.first(where: { $0.id == currentTrackId })
    }

// MARK: - AUDIO CONTROL
    func togglePlayPause(for track: Track) {
        guard let previewUrl = track.previewUrl ?? track.preview, let url = URL(string: previewUrl) else { return }
        // Synchronize track state
        syncCurrentTrack(track: track)

        // Vérifie si le player joue déjà ce morceau
        // let urlTest = "https://audiocdn.epidemicsound.com/lqmp3/01K1WWG258YTCAZJMGZH0KXSYY.mp3"

        // Met à jour l'index courant (dans syncCurrentTrack maintenant)
        /* if let idx = viewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            currentTrackIndex = idx
        }

        let tracks = viewModel.tracks
        if (!tracks.isEmpty && currentTrackIndex == 0) {
            for i in tracks.indices {
                viewModel.tracks[i].hasPlayed = false
                viewModel.tracks[i].isCurrentlyPlaying = false
            }
            viewModel.tracks[0].hasPlayed = false
            viewModel.tracks[0].isCurrentlyPlaying = true
        } */

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
            // Un autre morceau : pause l'ancien player
            audioPlayer?.pause()
            isPlaying = false
            // Nouveau morceau : crée un nouveau player et joue
            audioPlayer = AVPlayer(url: url)
            audioPlayer?.play()
            isPlaying = true
        }
    }

    func playTrack(_ track: Track) {
        guard let previewUrl = track.previewUrl ?? track.preview, let url = URL(string: previewUrl) else { return }
        audioPlayer?.pause()
        audioPlayer = AVPlayer(url: url)
        audioPlayer?.play()
        isPlaying = true

        syncCurrentTrack(track: track)

        // Retire l'ancien observer si besoin
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: audioPlayer?.currentItem)
        // Ajoute un nouvel observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem
        )
    }

    @objc private func trackDidFinishPlaying(_ notification: Notification) {
        DispatchQueue.main.async {
            self.nextTrack()
        }
    }

   func nextTrack() {
       guard !tracks.isEmpty else { return }

       currentTrackIndex = (currentTrackIndex + 1) % tracks.count

       let track = tracks[currentTrackIndex]
      //  togglePlayPause(for: track)
      playTrack(track)
   }

   func previousTrack() {
      guard !tracks.isEmpty, currentTrackIndex != 0 else { return }

       currentTrackIndex = (currentTrackIndex - 1 + tracks.count) % tracks.count

       let track = tracks[currentTrackIndex]
      //  togglePlayPause(for: track)
      playTrack(track)
   }

  func syncCurrentTrack(track: Track) {

      guard let currentIndex = self.tracks.firstIndex(where: { $0.id == track.id }) else { return }
      self.currentTrackId = track.id

      // Met à jour tous les états des tracks
      for (i, _) in self.tracks.enumerated() {
          self.tracks[i].isCurrentlyPlaying = (i == currentIndex)
          self.tracks[i].hasPlayed = (i < currentIndex)
      }

      // Send current track change via socket
      // SocketService.shared.updateCurrentTrack(trackId: track.id, playlistId: viewModel.playlist.id)
  }


    // MARK: - Socket Setup
    private func setupSocketListeners() {
        // REJOINDRE LA ROOM DE L'EVENT
        guard let eventId = playlist.eventId else {
            print("❌ Erreur: Aucun eventId associé à cette playlist")
            return
        }

        self.eventsSocket.joinEvent(eventId: eventId)

        eventsSocket.on("joined-events-room") { data, ack in
            print("✅ Successfully joined event room: \(data)")
        }
        
        // Écoute les utilisateurs qui rejoignent
        /* eventsSocket.onUserJoined { [weak self] data, ack in
            guard let self = self,
                  let userData = data.first as? [String: Any],
                  let user = self.parseUser(from: userData) else { return }
            
            DispatchQueue.main.async {
                self.users.append(user)
            }
        } */

        // Écoute les utilisateurs qui quittent
        eventsSocket.onUserLeft { [weak self] data, ack in
            guard let self = self,
                  let userData = data.first as? [String: Any],
                  let userId = userData["userId"] as? String else { return }
            
            DispatchQueue.main.async {
                self.users.removeAll { $0.id == userId }
            }
        }
        
        // Écoute les votes sur les tracks
        eventsSocket.on("vote-updated") { [weak self] data, ack in

            print("Vote update received via socket: \(data)")
            guard let self = self,
                  let voteData = data.first as? [String: Any],
                  let eventId = voteData["eventId"] as? String,
                  let vote = voteData["vote"] as? [String: Any],
                  let trackId = vote["trackId"] as? String,
                  let type = vote["type"] as? String else { return }
            
            DispatchQueue.main.async {
                  if let index = self.tracks.firstIndex(where: { $0.id == trackId }) {
                      if type == "upvote" {
                          self.tracks[index].likes = (self.tracks[index].likes ?? 0) + 1
                      } else if type == "downvote" {
                          self.tracks[index].dislikes = (self.tracks[index].dislikes ?? 0) + 1
                      }
                      self.sortUpcomingTracks()
                }
            }
        }

        // Écoute les ajouts de tracks
        eventsSocket.on("track-added") { [weak self] data, ack in
            print("track-added received via socket: \(data)")
            guard let self = self,
                  let addTrackData = data.first as? [String: Any],
                  let track = addTrackData["track"] as? [String: Any],
                  let eventId = addTrackData["eventId"] as? String,
                  let newTrack = Track(from: track) else { return }

            DispatchQueue.main.async {
                  self.tracks.append(newTrack)
                  self.sortUpcomingTracks()
            }
        }


        // Écoute les suppressions de tracks
        eventsSocket.on("track-removed") { [weak self] data, ack in
            print("Track-removed received via socket: \(data)")
            guard let self = self,
                  let rmTrackData = data.first as? [String: Any],
                  let eventId = rmTrackData["eventId"] as? String,
                  let trackId = rmTrackData["trackId"] as? String,
                  let removedBy = rmTrackData["removedBy"] as? String,
                  let timestamp = rmTrackData["timestamp"] as? String else { return }
            
            DispatchQueue.main.async {
                  self.tracks.removeAll { $0.id == trackId }
                  self.sortUpcomingTracks()
            }
        }
        
        // Écoute les suggestions de tracks 📌 pas fait
        eventsSocket.on("trackSuggested") { [weak self] data, ack in
            guard let self = self,
                  let suggestionData = data.first as? [String: Any] else { return }
            
            DispatchQueue.main.async {
                // Traiter la nouvelle suggestion
                print("Nouvelle suggestion reçue: \(suggestionData)")
            }
        }
        
        // Écoute les changements de track 📌 pas fait !! 
        eventsSocket.on("now-playing") { [weak self] data, ack in

            print("now-playing received via socket: \(data)")

            guard let self = self,
                let trackData = data.first as? [String: Any],
                let currentTrackId = trackData["trackId"] as? String? else { return }

            if let currentTrackId = trackData["trackId"] as? String {
                if let track = tracks.first(where: { $0.id == currentTrackId }) {
                    syncCurrentTrack(track: track)
                }
            }
            
            DispatchQueue.main.async {
                // Mettre à jour la track actuelle
                self.currentTrackId = currentTrackId
            }
        }
        
        // Écoute les changements d'état de lecture 📌 pas fait
        eventsSocket.on("playbackStateChanged") { [weak self] data, ack in
            guard let self = self,
                  let playbackData = data.first as? [String: Any],
                  let isPlaying = playbackData["isPlaying"] as? Bool else { return }
            
            DispatchQueue.main.async {
                // Mettre à jour l'état de lecture
                if let currentTrackId = self.currentTrackId,
                   let index = self.tracks.firstIndex(where: { $0.id == currentTrackId }) {
                    // Mise à jour de l'état de lecture si nécessaire
                    print("État de lecture mis à jour: \(isPlaying)")
                }
            }
        }

        devicesSocket.onPlaybackStateUpdated { [weak self] data, ack in
            print("📡 Playback state updated:", data)
    guard let self = self,
          let dict = data.first as? [String: Any] else {
        print("❌ Erreur : Données invalides ou vides")
        return
    }
    
    // Étape 2 : Extraire les clés individuelles
    let deviceIdentifier = dict["deviceIdentifier"] as? String
    let timestamp = dict["timestamp"] as? String
    let command = dict["command"] as? String
    
    // Étape 3 : Extraire le sous-dictionnaire `state`
    /* guard let state = dict["state"] as? [String: Any] else {
        print("❌ Erreur : État manquant dans les données")
        return
    }
    
    // Étape 4 : Extraire les valeurs spécifiques de `state`
    let isPlaying = state["isPlaying"] as? Bool  // true/false (NSNumber 1/0 est converti automatiquement)
    let volume = state["volume"] as? Float
    let position = state["position"] as? Double */

            switch command {
                case "play":
                    audioPlayer?.play()
                    isPlaying = true
                case "pause":
                    audioPlayer?.pause()
                    isPlaying = false
                case "next":
                    nextTrack()
                    
                case "previous":
                    previousTrack()
                    
                /* case "setVolume":
                    if let volume = data?["volume"] as? Float {
                        audioPlayer?.volume = volume
                        self.volume = volume
                    }
                    
                case "seek":
                    if let position = data?["position"] as? Double {
                        let time = CMTime(seconds: position, preferredTimescale: 1)
                        audioPlayer?.seek(to: time)
                    }
                     */
                default:
                    print("Commande inconnue: \(command)")
            }
        }

    }

    private func updateEvent(from data: [String: Any]) {
        // Met à jour l'événement avec les nouvelles données
        print("Event mis à jour: \(data)")
    }
}