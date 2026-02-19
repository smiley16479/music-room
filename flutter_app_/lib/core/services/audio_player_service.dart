import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Audio Player Service - handles audio playback using just_audio
class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioPlayer get player => _audioPlayer;

  /// Get the current player state stream
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Get the current position stream
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Get the buffered position stream
  Stream<Duration> get bufferedPositionStream => _audioPlayer.bufferedPositionStream;

  /// Get the duration stream
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// Get the current position
  Duration get position => _audioPlayer.position;

  /// Get the current duration
  Duration? get duration => _audioPlayer.duration;

  /// Get the current volume
  double get volume => _audioPlayer.volume;

  /// Check if audio is playing
  bool get isPlaying => _audioPlayer.playing;

  /// Load audio from URL and optionally start playback.
  /// If [startAt] is provided, seek to that position after loading.
  /// Avoids stopping/resetting position before setting the URL to prevent
  /// unwanted restarts when a client intends to immediately seek after loading.
  Future<void> playFromUrl(String url, {Duration? startAt, bool autoPlay = true}) async {
    try {
      debugPrint('🔊 playFromUrl: url=$url startAt=$startAt autoPlay=$autoPlay');
      // Set the new URL (just_audio completes when the source is ready)
      await _audioPlayer.setUrl(url);

      // Wait until the player reports it's ready (or buffering/completed) before seeking
      await _audioPlayer.playerStateStream.firstWhere((state) {
        final ps = state.processingState;
        return ps == ProcessingState.ready || ps == ProcessingState.buffering || ps == ProcessingState.completed;
      });

      // If a start position was provided, seek to it after the source is ready
      if (startAt != null) {
        await _audioPlayer.seek(startAt);
      }

      // Start playback only if requested
      if (autoPlay) {
        debugPrint('🔊 calling play() after setUrl');
        await _audioPlayer.play();
        debugPrint('🔊 position after play: ${_audioPlayer.position}');
      }
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      rethrow;
    }
  }

  /// Play
  Future<void> play() async {
    debugPrint('🔊 play(): current position=${_audioPlayer.position}');
    await _audioPlayer.play();
  }

  /// Pause
  Future<void> pause() async {
    debugPrint('🔊 pause(): current position=${_audioPlayer.position}');
    await _audioPlayer.pause();
  }

  /// Stop
  Future<void> stop() async {
    debugPrint('🔊 stop(): current position=${_audioPlayer.position}');
    // Note: do NOT call pause() here before stop().
    // Calling pause() on a completed player re-emits
    // ProcessingState.completed, which would incorrectly trigger
    // auto-advance a second time and skip every other track.
    await _audioPlayer.stop(); // Transitions directly to idle state
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    debugPrint('🔊 seek(): from=${_audioPlayer.position} to=$position');
    await _audioPlayer.seek(position);
  }

  /// Seek to position and then play (ensures seek completes before playing)
  Future<void> seekAndPlay(Duration position) async {
    debugPrint('🔊 seekAndPlay(): seeking from=${_audioPlayer.position} to=$position');
    await _audioPlayer.seek(position);
    debugPrint('🔊 seekAndPlay(): seek complete, now playing from=${_audioPlayer.position}');
    await _audioPlayer.play();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Dispose the audio player
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
