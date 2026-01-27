import 'package:just_audio/just_audio.dart';

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

  /// Play audio from URL
  Future<void> playFromUrl(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      print('❌ Error playing audio: $e');
      rethrow;
    }
  }

  /// Play
  Future<void> play() async {
    await _audioPlayer.play();
  }

  /// Pause
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Stop
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
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
