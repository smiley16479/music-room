import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../config/app_config.dart';
import '../models/playlist_track.dart';
import '../services/audio_player_service.dart';

/// Audio Player Provider - manages audio playback state globally
class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService;

  // Current track info
  PlaylistTrack? _currentTrack;
  List<PlaylistTrack> _playlist = [];
  int _currentIndex = -1;

  // Player state
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 0.7;
  String? _error;

  AudioPlayerProvider({required AudioPlayerService audioService})
      : _audioService = audioService {
    _initListeners();
  }

  // Getters
  PlaylistTrack? get currentTrack => _currentTrack;
  List<PlaylistTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  String? get error => _error;
  bool get hasCurrentTrack => _currentTrack != null;

  /// Initialize stream listeners
  void _initListeners() {
    _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      // Auto-play next track when current one completes
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }

      notifyListeners();
    });

    _audioService.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    _audioService.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });
  }

  /// Play a single track
  Future<void> playTrack(PlaylistTrack track) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      // First, try to get full audio stream from YouTube via backend
      String? audioUrl = await _getFullAudioStreamUrl(track.trackId);
      
      // Fallback to stored preview URL if YouTube stream fails
      if (audioUrl == null || audioUrl.isEmpty) {
        audioUrl = _getPreviewUrl(track);
        debugPrint('⚠️ Using Deezer preview (30s) for ${track.trackTitle}');
      } else {
        debugPrint('🎵 Playing full track from YouTube for ${track.trackTitle}');
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        _error = 'No audio available for this track';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentTrack = track;
      await _audioService.playFromUrl(audioUrl);
      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to play track: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch full audio stream URL from backend proxy
  /// The backend will proxy the audio through the server using yt-dlp
  Future<String?> _getFullAudioStreamUrl(String trackId) async {
    try {
      // Use the audio proxy endpoint - it streams YouTube audio via yt-dlp
      final audioProxyUrl = '${AppConfig.baseUrl}/music/track/$trackId/audio-proxy';
      
      debugPrint('🎵 Using YouTube audio proxy: $audioProxyUrl');
      
      // Return the proxy URL directly - just_audio will handle streaming from it
      return audioProxyUrl;
    } catch (e) {
      debugPrint('❌ Error preparing audio proxy: $e');
      return null;
    }
  }
  /// Play a playlist starting from a specific track
  Future<void> playPlaylist(List<PlaylistTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;

    _playlist = List.from(tracks);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    // Clear current track to ensure proper initialization when switching tracks
    _currentTrack = null;
    await playTrack(_playlist[_currentIndex]);
  }

  /// Get preview URL for a track (Deezer preview)
  String? _getPreviewUrl(PlaylistTrack track) {
    // First, try to use the stored preview URL
    if (track.previewUrl != null && track.previewUrl!.isNotEmpty) {
      return track.previewUrl;
    }
    
    // Fallback: construct Deezer preview URL from track ID
    // This is a backup in case the previewUrl wasn't stored
    return 'https://cdns-preview-d.dzcdn.net/stream/c-${track.trackId}';
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.play();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioService.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await _audioService.play();
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioService.stop();
    _currentTrack = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioService.setVolume(_volume);
    notifyListeners();
  }

  /// Play next track in playlist
  Future<void> _playNext() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await playTrack(_playlist[_currentIndex]);
    } else {
      // End of playlist
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Skip to next track
  Future<void> skipNext() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length - 1) return;
    await _playNext();
  }

  /// Skip to previous track
  Future<void> skipPrevious() async {
    if (_playlist.isEmpty) return;

    // If we're more than 3 seconds in, restart the current track
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      await playTrack(_playlist[_currentIndex]);
    }
  }

  /// Format duration for display
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
