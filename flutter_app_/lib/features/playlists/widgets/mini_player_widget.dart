import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/audio_player_provider.dart';
import '../../../core/providers/event_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/event.dart';

/// Mini Player Widget - displays at the bottom of the screen when music is playing
class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<AudioPlayerProvider, EventProvider?, AuthProvider?>(
      builder: (context, audioProvider, eventProvider, authProvider, _) {
        // Only show if there's a current track
        if (!audioProvider.hasCurrentTrack) {
          return const SizedBox.shrink();
        }

        final track = audioProvider.currentTrack!;
        final isPlaying = audioProvider.isPlaying;
        final isLoading = audioProvider.isLoading;
        
        // Check if the current playlist is an event and if user is admin/owner
        final currentPlaylist = eventProvider?.currentPlaylist;
        final currentUser = authProvider?.currentUser;
        final isEventPlaylist = currentPlaylist?.type == EventType.event;
        final isOwner = currentUser?.id == currentPlaylist?.creatorId;
        
        // Disable play/pause for non-admin users in event playlists
        final canControlPlayback = !isEventPlaylist || isOwner;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: audioProvider.duration.inMilliseconds > 0
                    ? audioProvider.position.inMilliseconds /
                        audioProvider.duration.inMilliseconds
                    : 0,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
                minHeight: 2,
              ),
              // Player content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // Album cover
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade300,
                      ),
                      child: track.coverUrl != null && track.coverUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                track.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.music_note,
                                    color: Colors.grey.shade600,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.music_note,
                              color: Colors.grey.shade600,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Track info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.trackTitle ?? 'Unknown Track',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.trackArtist ?? 'Unknown Artist',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Volume control
                    _VolumeControl(audioProvider: audioProvider),
                    const SizedBox(width: 8),
                    // Play/Pause button (hidden for non-admin users in event playlists)
                    if (canControlPlayback)
                      IconButton(
                        icon: isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                        onPressed: isLoading
                            ? null
                            : () => audioProvider.togglePlayPause(),
                      ),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => audioProvider.stop(),
                      tooltip: 'Stop',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Volume control widget with slider
class _VolumeControl extends StatefulWidget {
  final AudioPlayerProvider audioProvider;

  const _VolumeControl({required this.audioProvider});

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _showVolumeSlider = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showVolumeSlider)
          SizedBox(
            width: 100,
            child: Slider(
              value: widget.audioProvider.volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) => widget.audioProvider.setVolume(value),
            ),
          ),
        IconButton(
          icon: Icon(
            widget.audioProvider.volume == 0
                ? Icons.volume_off
                : widget.audioProvider.volume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _showVolumeSlider = !_showVolumeSlider;
            });
          },
          tooltip: 'Volume',
        ),
      ],
    );
  }
}

/// Extended Mini Player with more controls (for future use)
class ExpandedPlayerWidget extends StatelessWidget {
  const ExpandedPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<AudioPlayerProvider, EventProvider?, AuthProvider?>(
      builder: (context, audioProvider, eventProvider, authProvider, _) {
        if (!audioProvider.hasCurrentTrack) {
          return const SizedBox.shrink();
        }

        final track = audioProvider.currentTrack!;
        
        // Check if the current playlist is an event and if user is admin/owner
        final currentPlaylist = eventProvider?.currentPlaylist;
        final currentUser = authProvider?.currentUser;
        final isEventPlaylist = currentPlaylist?.type == EventType.event;
        final isOwner = currentUser?.id == currentPlaylist?.creatorId;
        
        // Disable play/pause for non-admin users in event playlists
        final canControlPlayback = !isEventPlaylist || isOwner;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Now Playing'),
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Album cover
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade300,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: track.coverUrl != null && track.coverUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            track.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.music_note,
                                size: 80,
                                color: Colors.grey.shade600,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.music_note,
                          size: 80,
                          color: Colors.grey.shade600,
                        ),
                ),
                const SizedBox(height: 32),
                // Track info
                Text(
                  track.trackTitle ?? 'Unknown Track',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  track.trackArtist ?? 'Unknown Artist',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (track.trackAlbum != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      track.trackAlbum!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 32),
                // Progress slider
                Column(
                  children: [
                    Slider(
                      value: audioProvider.duration.inMilliseconds > 0
                          ? audioProvider.position.inMilliseconds /
                              audioProvider.duration.inMilliseconds
                          : 0,
                      onChanged: (value) {
                        final position = Duration(
                          milliseconds:
                              (value * audioProvider.duration.inMilliseconds)
                                  .round(),
                        );
                        audioProvider.seek(position);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            audioProvider.formatDuration(audioProvider.position),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            audioProvider.formatDuration(audioProvider.duration),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      iconSize: 48,
                      onPressed: () => audioProvider.skipPrevious(),
                    ),
                    const SizedBox(width: 24),
                    // Play/Pause button (hidden for non-admin users in event playlists)
                    if (canControlPlayback)
                      IconButton(
                        icon: audioProvider.isLoading
                            ? const SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(strokeWidth: 3),
                              )
                            : Icon(
                                audioProvider.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                              ),
                        iconSize: 72,
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: audioProvider.isLoading
                            ? null
                            : () => audioProvider.togglePlayPause(),
                      ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      iconSize: 48,
                      onPressed: () => audioProvider.skipNext(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Volume control
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      audioProvider.volume == 0
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: Colors.grey,
                    ),
                    SizedBox(
                      width: 200,
                      child: Slider(
                        value: audioProvider.volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (value) => audioProvider.setVolume(value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
