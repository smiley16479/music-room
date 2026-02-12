import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/audio_player_provider.dart';
import '../../../core/providers/event_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/event.dart';
import '../../../core/services/websocket_service.dart';
import '../screens/event_details_screen.dart';
import '../screens/playlist_details_screen.dart';

/// A wrapper that adds the mini player to any screen
/// This ensures the music player is visible across all screens when playing
class MiniPlayerScaffold extends StatelessWidget {
  final Widget child;
  final bool showMiniPlayer;

  const MiniPlayerScaffold({
    super.key,
    required this.child,
    this.showMiniPlayer = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showMiniPlayer) {
      return child;
    }

    return Consumer3<AudioPlayerProvider?, EventProvider?, AuthProvider?>(
      builder: (context, audioProvider, eventProvider, authProvider, _) {
        // Defensive: provider may be null in some widget trees (e.g. during hot-reload)
        if (audioProvider == null || audioProvider.hasCurrentTrack == false) {
          return child;
        }

        final track = audioProvider.currentTrack!;
        final isPlaying = audioProvider.isPlaying;
        final isLoading = audioProvider.isLoading;

        // All users can control their own local playback
        // Admin controls are server-synced, non-admin controls are local only

        return Column(
          children: [
            Expanded(child: child),
            // Mini player
            Container(
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
              child: SafeArea(
                top: false,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Album cover + Track info — tappable to navigate to playlist
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                // Use the source playlist the track was started
                                // from, not whatever playlist is currently viewed.
                                final playlistId =
                                    audioProvider.sourcePlaylistId;
                                if (playlistId == null) return;

                                final sourceType =
                                    audioProvider.sourcePlaylistType;

                                // If we're already inside a PlaylistDetailsScreen,
                                // check whether it's the same playlist before navigating.
                                final ancestor = context
                                    .findAncestorWidgetOfExactType<
                                      PlaylistDetailsScreen
                                    >();
                                if (ancestor != null) {
                                  if (ancestor.playlistId == playlistId) {
                                    // Already viewing the correct playlist — do nothing.
                                    return;
                                  }

                                  if (sourceType == EventType.event) {
                                    // Source is an event: pop back then push EventDetails → PlaylistDetails
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => EventDetailsScreen(
                                          eventId: playlistId,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Source is a standard playlist: just replace with PlaylistDetails
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => PlaylistDetailsScreen(
                                          playlistId: playlistId,
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // Check if we're on EventDetailsScreen viewing a different event
                                final eventAncestor = context
                                    .findAncestorWidgetOfExactType<
                                      EventDetailsScreen
                                    >();

                                if (sourceType == EventType.event) {
                                  if (eventAncestor != null &&
                                      eventAncestor.eventId == playlistId) {
                                    // Already on the correct EventDetailsScreen — just push playlist on top
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PlaylistDetailsScreen(
                                          playlistId: playlistId,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Push EventDetailsScreen (back button goes to previous screen)
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EventDetailsScreen(
                                          eventId: playlistId,
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  // Standard playlist — push PlaylistDetailsScreen directly.
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PlaylistDetailsScreen(
                                        playlistId: playlistId,
                                      ),
                                    ),
                                  );
                                }
                              },
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
                                    child:
                                        track.coverUrl != null &&
                                            track.coverUrl!.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Image.network(
                                              track.coverUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.music_note,
                                                      color:
                                                          Colors.grey.shade600,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          track.trackTitle ?? 'Unknown Track',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          track.trackArtist ?? 'Unknown Artist',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Material(
                              type: MaterialType.transparency,
                              child: _VolumeControl(
                                audioProvider: audioProvider,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Play/Pause button — local playback control for all users
                          IconButton(
                            icon: isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                          // Stop button — stops playback and leaves event playlist room
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              // If playing from an event playlist, leave the room
                              final sourceId = audioProvider.sourcePlaylistId;
                              final sourceType =
                                  audioProvider.sourcePlaylistType;
                              if (sourceId != null &&
                                  sourceType == EventType.event) {
                                try {
                                  final ws = context.read<WebSocketService>();
                                  ws.leaveEventPlaylist(sourceId);
                                  debugPrint(
                                    '🎵 Left event playlist room on stop: $sourceId',
                                  );
                                } catch (e) {
                                  debugPrint(
                                    'Error leaving event playlist on stop: $e',
                                  );
                                }
                              }
                              audioProvider.stop();
                              // Pop back if currently viewing the playlist
                              final ancestor = context
                                  .findAncestorWidgetOfExactType<
                                    PlaylistDetailsScreen
                                  >();
                              if (ancestor != null &&
                                  ancestor.playlistId == sourceId) {
                                Navigator.of(context).pop();
                              }
                            },
                            tooltip: 'Stop & Leave',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          // allow the slider to shrink when there's not enough space
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Slider(
                value: widget.audioProvider.volume,
                min: 0.0,
                max: 1.0,
                onChanged: (value) => widget.audioProvider.setVolume(value),
              ),
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
