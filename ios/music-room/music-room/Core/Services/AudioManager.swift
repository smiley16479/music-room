//
//  AudioManager.swift
//  music-room
//
//  Created by system on 30/09/2025.
//

import Foundation
import AVFoundation
import CoreMedia

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var isPlaying: Bool = false
    @Published var currentTrack: Track?
    @Published var volume: Float = 0.5
    
    private var audioPlayer: AVPlayer?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Erreur lors de la configuration de la session audio: \(error)")
        }
    }
    
    func playTrack(_ track: Track) {
        guard let previewUrl = track.previewUrl ?? track.preview,
              let url = URL(string: previewUrl) else { 
            print("❌ URL invalide pour la track: \(track.title)")
            return 
        }
        
        // Arrêter et nettoyer l'ancien player
        stopCurrentTrack()
        
        // Créer et démarrer le nouveau player
        audioPlayer = AVPlayer(url: url)
        audioPlayer?.play()
        
        // Mettre à jour l'état
        currentTrack = track
        isPlaying = true
        
        print("🎵 Lecture démarrée: \(track.title)")
        
        // Ajouter observer pour la fin de lecture
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem
        )
    }
    
    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
            print("⏸️ Lecture mise en pause")
        } else {
            player.play()
            isPlaying = true
            print("▶️ Lecture reprise")
        }
    }
    
    func stopCurrentTrack() {
        // Supprimer l'observer de l'ancien player
        if let currentItem = audioPlayer?.currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
        
        // Arrêter et nettoyer
        audioPlayer?.pause()
        audioPlayer = nil
        
        if isPlaying {
            isPlaying = false
            print("⏹️ Lecture arrêtée")
        }
    }
    
    func setVolume(_ volume: Float) {
        self.volume = volume
        audioPlayer?.volume = volume
    }
    
    func seekTo(position: Double) {
        guard let player = audioPlayer else { return }
        let time = CMTime(seconds: position, preferredTimescale: 1)
        player.seek(to: time)
    }
    
    @objc private func trackDidFinishPlaying(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTrack = nil
            print("🔚 Fin de lecture de la track")
            
            // Ici tu peux ajouter la logique pour passer à la track suivante
            // ou notifier le ViewModel concerné
        }
    }
    
    deinit {
        stopCurrentTrack()
        NotificationCenter.default.removeObserver(self)
    }
}