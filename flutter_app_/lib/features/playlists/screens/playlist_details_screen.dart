import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/index.dart';
import '../../../core/providers/index.dart';
import '../../../core/services/index.dart';
import '../../../core/navigation/route_observer.dart';
import '../widgets/music_search_dialog.dart';
import '../widgets/collaborator_dialog.dart';
import '../widgets/mini_player_scaffold.dart';
import '../widgets/track_voting_widget.dart';

/// Playlist Details screen
class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailsScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

// MARK: - PlaylistDetailsScreen
class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen>
    with RouteAware {
  ModalRoute<dynamic>? _modalRoute;
  WebSocketService? _wsService;
  bool _isEditMode = false;
  bool _hasJoinedRoom = false;
  bool _hasLoadedPlaylist = false;
  // Seek UI state for admin-controlled seeking
  double _seekValue = 0.0;
  bool _isSeeking = false;
  // Current user id – cached so socket handlers can skip own events via controlledBy
  String? _currentUserId;
  // Track play/pause state changes from the audio player to emit socket events
  bool? _lastKnownPlayingState;
  AudioPlayerProvider? _audioProvider;
  bool _isListeningToAudio = false;
  // Flag to suppress socket emit when audio state change came from a socket handler
  bool _handlingSocketEvent = false;

  // --- Server-driven stream state ---
  // These hold the latest server time-sync data for the admin seek bar.
  // The admin seek bar reflects the *server* position (not local player).
  double _serverPosition = 0.0;
  double _serverDuration = 0.0;
  bool _serverIsPlaying = false;
  String? _serverTrackId;
  DateTime? _lastTimeSyncReceived;

  // Text Controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  // Playlist settings
  late EventVisibility? _selectedVisibility; // Public/Private
  late bool _votingInvitedOnly; // License type

  @override
  void initState() {
    super.initState();
    _initControllers();
    // Load playlist and join room after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoadedPlaylist) {
        _hasLoadedPlaylist = true;
        _loadPlaylist();
        _joinEventPlaylistRoom();
      }
    });
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _selectedVisibility = null;
    _votingInvitedOnly = false;
  }

  /// Listener for AudioPlayerProvider state changes.
  /// In the new server-driven model:
  /// - Admin/Delegated: does NOT emit socket events here. Admin controls use dedicated buttons.
  /// - Non-admin: when pressing play after a local pause, request sync from server.
  void _onAudioStateChanged() {
    if (!mounted || _handlingSocketEvent) return;

    final audioProvider = _audioProvider;
    if (audioProvider == null) return;

    // Only act for event playlists
    bool canControl = false;
    try {
      final eventProvider = context.read<EventProvider>();
      final authProvider = context.read<AuthProvider>();
      final deviceProvider = context.read<DeviceProvider>();
      final playlist = eventProvider.currentPlaylist;
      if (playlist == null || playlist.type != EventType.event) return;
      
      // Check if user can control (owner OR delegated)
      canControl = _canControlPlayback(
        playlist.creatorId,
        deviceProvider.delegatedDevices,
        authProvider.currentUser?.id,
      );
    } catch (_) {
      return;
    }

    final isPlaying = audioProvider.isPlaying;

    // Only act when the state actually transitions
    if (_lastKnownPlayingState == null || _lastKnownPlayingState == isPlaying) {
      _lastKnownPlayingState = isPlaying;
      return;
    }

    if (canControl) {
      // Admin/Delegated: pressing play/pause on the local audio player should NOT
      // change local state independently. Instead, revert the action and
      // let the server drive via the dedicated admin buttons.
      if (isPlaying && !_serverIsPlaying) {
        // User pressed play locally but server is paused → pause back locally
        debugPrint('🚫 Admin/Delegated local play blocked: server is paused, reverting');
        _handlingSocketEvent = true;
        _audioProvider?.pause();
        _handlingSocketEvent = false;
        // Don't update _lastKnownPlayingState since we reverted
        return;
      } else if (!isPlaying && _serverIsPlaying) {
        // Admin paused locally but server is playing → this is fine (local pause)
        // No action needed, local pause is allowed
      }
    } else {
      // Non-admin: when pressing play after local pause, request sync from server
      if (isPlaying) {
        final ws = _wsService;
        if (ws != null) {
          debugPrint('🔄 Non-admin play: requesting playback sync from server');
          ws.requestPlaybackSync(widget.playlistId);
        }
      }
      // Non-admin pause: do nothing (local only)
    }
    _lastKnownPlayingState = isPlaying;
  }

  void _joinEventPlaylistRoom() {
    if (_hasJoinedRoom) return;

    try {
      final ws = _wsService ?? context.read<WebSocketService>();
      _wsService ??= ws;
      ws.joinEventPlaylist(widget.playlistId);
      _hasJoinedRoom = true;

      // Start listening to audio player state changes for admin sync
      if (!_isListeningToAudio) {
        _audioProvider = context.read<AudioPlayerProvider>();
        _lastKnownPlayingState = _audioProvider!.isPlaying;
        _audioProvider!.addListener(_onAudioStateChanged);
        _isListeningToAudio = true;
      }

      // Set up track completion callback for event playlists.
      // Server-driven: no client should auto-advance or emit track-ended.
      // The server's EventStreamService handles track progression autonomously.
      try {
        final eventProvider = context.read<EventProvider>();
        final playlist = eventProvider.currentPlaylist;
        if (playlist != null && playlist.type == EventType.event) {
          // Both admin and non-admin: do nothing on track complete.
          // Server drives progression.
          _audioProvider!.onTrackCompleted = (_) {
            debugPrint('🏁 Track completed locally: server drives progression');
          };
          // Disable auto-advance for event playlists to prevent desync
          _audioProvider!.disableAutoAdvance();
        }
      } catch (_) {}

      // Cache current user id for filtering own socket events
      try {
        _currentUserId ??= context.read<AuthProvider>().currentUser?.id;
      } catch (_) {}

      // Listen for users joining/leaving the playlist room
      ws.on('user-joined-playlist', (data) {
        if (mounted) {
          debugPrint('🎵 User joined playlist: ${data['displayName']}');
        }
      });

      ws.on('user-left-playlist', (data) {
        if (mounted) {
          debugPrint('🎵 User left playlist: ${data['displayName']}');
        }
      });

      // NOTE: track-added, track-removed, and queue-reordered are handled
      // by EventProvider's global listeners. Do NOT register handlers here
      // because off() in cleanup would destroy EventProvider's listeners too.
      //
      // However, we register a callback on EventProvider so that if the
      // currently-playing track is removed we stop the local audio player.
      try {
        final eventProvider = context.read<EventProvider>();
        eventProvider.onTrackRemoved = (removedTrackId) async {
          if (!mounted) return;
          final audioProvider = context.read<AudioPlayerProvider>();
          if (audioProvider.currentTrack?.trackId == removedTrackId) {
            debugPrint(
              '⏹️ Currently-playing track removed — stopping audio player',
            );
            _handlingSocketEvent = true;
            await audioProvider.stop();
            _handlingSocketEvent = false;
            _lastKnownPlayingState = false;
            if (mounted) {
              setState(() {
                _serverTrackId = null;
                _serverIsPlaying = false;
                _serverPosition = 0;
                _serverDuration = 0;
                _lastTimeSyncReceived = null;
              });
            }
          }
        };
      } catch (_) {}

      ws.on('vote-updated', (data) {
        if (mounted) {
          debugPrint('🗳️ Vote updated: $data');
          // VotingProvider has its own global listener, just refresh UI
          if (mounted) setState(() {});
        }
      });

      ws.on('music-play', (data) async {
        if (!mounted) return;

        final controlledBy = data['controlledBy'];
        debugPrint('📥 Received music-play event: controlledBy=$controlledBy');

        try {
          final trackId = data['trackId'];
          final startTime = data['startTime'];

          // Update server state immediately so admin buttons reflect correct state
          if (mounted) {
            setState(() {
              _serverIsPlaying = true;
              if (trackId != null) _serverTrackId = trackId as String;
              if (startTime != null) {
                _serverPosition = (startTime is double)
                    ? startTime
                    : (startTime as num).toDouble();
              }
              _lastTimeSyncReceived = DateTime.now();
            });
          }

          final audioProvider = context.read<AudioPlayerProvider>();
          final eventProvider = context.read<EventProvider>();

          _handlingSocketEvent = true;

          // Check if we need to load a different track
          final needsTrackLoad =
              trackId != null &&
              trackId.toString().isNotEmpty &&
              (audioProvider.currentTrack == null ||
                  audioProvider.currentTrack!.trackId != trackId);

          debugPrint(
            '▶️ Processing music-play: trackId=$trackId, startTime=$startTime, needsTrackLoad=$needsTrackLoad',
          );

          if (needsTrackLoad) {
            final tracks = eventProvider.currentPlaylistTracks;
            if (tracks.isNotEmpty) {
              final index = tracks.indexWhere((t) => t.trackId == trackId);
              final startIndex = index >= 0 ? index : 0;
              await audioProvider.playPlaylist(
                tracks,
                startIndex: startIndex,
                autoPlay: false,
                sourceType: eventProvider.currentPlaylist?.type,
              );
              // Wait for track to be ready before seeking
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }

          // Always seek to the server's position before resuming to stay in sync
          if (startTime != null && audioProvider.currentTrack != null) {
            final int targetSeconds = (startTime is double)
                ? startTime.round()
                : (startTime as num).toInt();

            debugPrint('▶️ Seeking to $targetSeconds seconds');
            await audioProvider.seek(Duration(seconds: targetSeconds));
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Resume playback to sync with server
          if (audioProvider.currentTrack != null && !audioProvider.isPlaying) {
            debugPrint('▶️ Resuming playback');
            await audioProvider.resume();
          }

          _handlingSocketEvent = false;
          _lastKnownPlayingState = audioProvider.isPlaying;
        } catch (e) {
          _handlingSocketEvent = false;
          debugPrint('Error handling music-play: $e');
        }
      });

      ws.on('music-pause', (data) async {
        if (!mounted) return;

        final controlledBy = data['controlledBy'];
        final trackId = data['trackId'];
        final reason = data['reason'] as String?;
        debugPrint(
          '📥 Received music-pause event: controlledBy=$controlledBy, trackId=$trackId, reason=$reason',
        );

        // If no trackId or reason is no_more_tracks, treat as stop/clear
        if (trackId == null || reason == 'no_more_tracks') {
          debugPrint('⏹️ Stopping playback (no trackId or no more tracks)');
          final audioProvider = context.read<AudioPlayerProvider>();
          await audioProvider.stop();
          _handlingSocketEvent = false;
          _lastKnownPlayingState = false;
          if (mounted) setState(() {});
          return;
        }

        try {
          final currentTime = data['currentTime'];

          // Update server state immediately so admin buttons reflect correct state
          if (mounted) {
            setState(() {
              _serverIsPlaying = false;
              if (trackId != null) _serverTrackId = trackId as String;
              if (currentTime != null) {
                _serverPosition = (currentTime is double)
                    ? currentTime
                    : (currentTime as num).toDouble();
              }
              _lastTimeSyncReceived = DateTime.now();
            });
          }

          final audioProvider = context.read<AudioPlayerProvider>();
          final eventProvider = context.read<EventProvider>();

          _handlingSocketEvent = true;

          // Check if we need to load a different track
          final needsTrackLoad =
              trackId.toString().isNotEmpty &&
              (audioProvider.currentTrack == null ||
                  audioProvider.currentTrack!.trackId != trackId);

          debugPrint(
            '⏸️ Processing music-pause: trackId=$trackId, currentTime=$currentTime, needsTrackLoad=$needsTrackLoad',
          );

          if (needsTrackLoad) {
            final tracks = eventProvider.currentPlaylistTracks;
            if (tracks.isNotEmpty) {
              final index = tracks.indexWhere((t) => t.trackId == trackId);
              final startIndex = index >= 0 ? index : 0;
              await audioProvider.playPlaylist(
                tracks,
                startIndex: startIndex,
                autoPlay: false,
                sourceType: eventProvider.currentPlaylist?.type,
              );
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }

          // Seek to the server's paused position
          if (currentTime != null && audioProvider.currentTrack != null) {
            final int targetSeconds = (currentTime is double)
                ? currentTime.round()
                : (currentTime as num).toInt();
            await audioProvider.seek(Duration(seconds: targetSeconds));
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Pause playback to sync with server
          if (audioProvider.currentTrack != null && audioProvider.isPlaying) {
            debugPrint('⏸️ Pausing playback');
            await audioProvider.pause();
          }

          _handlingSocketEvent = false;
          _lastKnownPlayingState = audioProvider.isPlaying;
        } catch (e) {
          _handlingSocketEvent = false;
          debugPrint('Error handling music-pause: $e');
        }
      });

      // Listen for server seek events and update local player position
      ws.on('music-seek', (data) async {
        if (!mounted) return;

        debugPrint('⏩ Received music-seek event: $data');

        try {
          final seekTime = data['seekTime'];
          final trackId = data['trackId'];
          final isPlaying = data['isPlaying'] == true;

          // Update server state immediately
          if (mounted) {
            setState(() {
              _serverIsPlaying = isPlaying;
              if (trackId != null) _serverTrackId = trackId as String;
              if (seekTime != null) {
                _serverPosition = (seekTime is double)
                    ? seekTime
                    : (seekTime as num).toDouble();
              }
              _lastTimeSyncReceived = DateTime.now();
            });
          }

          final audioProvider = context.read<AudioPlayerProvider>();
          final eventProvider = context.read<EventProvider>();

          _handlingSocketEvent = true;

          // Check if we need to load a track
          final needsTrackLoad =
              trackId != null &&
              trackId.isNotEmpty &&
              (audioProvider.currentTrack == null ||
                  audioProvider.currentTrack!.trackId != trackId);

          if (needsTrackLoad) {
            final tracks = eventProvider.currentPlaylistTracks;
            if (tracks.isNotEmpty) {
              final index = tracks.indexWhere((t) => t.trackId == trackId);
              final startIndex = index >= 0 ? index : 0;
              await audioProvider.playPlaylist(
                tracks,
                startIndex: startIndex,
                autoPlay: false,
                sourceType: eventProvider.currentPlaylist?.type,
              );
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }

          // Seek to the server's position
          if (seekTime != null && audioProvider.currentTrack != null) {
            final int seconds = (seekTime is double)
                ? seekTime.round()
                : (seekTime as num).toInt();
            await audioProvider.seek(Duration(seconds: seconds));
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Sync play/pause state with server
          if (audioProvider.currentTrack != null) {
            if (isPlaying && !audioProvider.isPlaying) {
              await audioProvider.resume();
            } else if (!isPlaying && audioProvider.isPlaying) {
              await audioProvider.pause();
            }
          }

          _handlingSocketEvent = false;
          _lastKnownPlayingState = audioProvider.isPlaying;
        } catch (e) {
          _handlingSocketEvent = false;
          debugPrint('Error handling music-seek: $e');
        }
      });

      ws.on('track-skipped', (data) {});

      // Handle music-stop: clear playback completely
      ws.on('music-stop', (data) async {
        if (!mounted) return;
        debugPrint('⏹️ Music stopped in playlist: $data');
        try {
          final audioProvider = context.read<AudioPlayerProvider>();
          _handlingSocketEvent = true;
          await audioProvider.stop();
          _handlingSocketEvent = false;
          _lastKnownPlayingState = false;
          if (mounted) {
            setState(() {
              _serverTrackId = null;
              _serverIsPlaying = false;
              _serverPosition = 0;
              _serverDuration = 0;
              _lastTimeSyncReceived = null;
            });
          }
        } catch (e) {
          _handlingSocketEvent = false;
          debugPrint('Error handling music-stop: $e');
        }
      });

      // Handle track-ended: remove the ended track, advance to next
      ws.on('track-ended', (data) async {
        if (!mounted) return;
        debugPrint('⏹️ Track ended in playlist: $data');
        try {
          final eventProvider = context.read<EventProvider>();
          final trackId = data['trackId'] as String?;
          if (trackId != null &&
              eventProvider.currentPlaylist?.id == widget.playlistId) {
            // Remove the ended track from local list
            eventProvider.removeTrackLocally(trackId);
            if (mounted) setState(() {});
          }
        } catch (e) {
          debugPrint('Error handling track-ended: $e');
        }
      });

      // Handle music-track-changed: load and play the new track
      ws.on('music-track-changed', (data) async {
        if (!mounted) return;
        debugPrint('🔄 Track changed in playlist: $data');
        try {
          final trackId = data['trackId'] as String?;
          final continuePlaying = data['continuePlaying'] == true;
          final trackDuration = data['trackDuration'];

          if (trackId == null) return;

          // Update server state
          setState(() {
            _serverTrackId = trackId;
            _serverPosition = 0;
            _serverIsPlaying = continuePlaying;
            if (trackDuration != null) {
              _serverDuration = (trackDuration is double)
                  ? trackDuration
                  : (trackDuration as num).toDouble();
            }
            _lastTimeSyncReceived = DateTime.now();
          });

          final audioProvider = context.read<AudioPlayerProvider>();
          final eventProvider = context.read<EventProvider>();

          _handlingSocketEvent = true;

          final tracks = eventProvider.currentPlaylistTracks;
          if (tracks.isEmpty) {
            await audioProvider.stop();
            _handlingSocketEvent = false;
            _lastKnownPlayingState = false;
            if (mounted) setState(() {});
            return;
          }

          final index = tracks.indexWhere((t) => t.trackId == trackId);
          final startIndex = index >= 0 ? index : 0;

          await audioProvider.playPlaylist(
            tracks,
            startIndex: startIndex,
            autoPlay: continuePlaying,
            sourceType: eventProvider.currentPlaylist?.type,
          );

          _handlingSocketEvent = false;
          _lastKnownPlayingState = continuePlaying;
          if (mounted) setState(() {});
        } catch (e) {
          _handlingSocketEvent = false;
          debugPrint('Error handling music-track-changed: $e');
        }
      });

      // Handle playback-sync: sync state when joining the room or after local play
      ws.on('playback-sync', (data) async {
        if (!mounted) return;
        debugPrint('🔄 Playback sync received: $data');
        try {
          final trackId = data['currentTrackId'] as String?;
          final startTime = data['startTime'];
          final isPlaying = data['isPlaying'] == true;

          if (trackId == null) return;

          final audioProvider = context.read<AudioPlayerProvider>();
          final eventProvider = context.read<EventProvider>();

          _handlingSocketEvent = true;

          // Update server state for admin seek bar
          if (mounted) {
            setState(() {
              _serverTrackId = trackId;
              _serverIsPlaying = isPlaying;
              if (startTime != null) {
                _serverPosition = (startTime is double)
                    ? startTime
                    : (startTime as num).toDouble();
              }
              _lastTimeSyncReceived = DateTime.now();
            });
          }

          // Check if we need to load this track
          final needsTrackLoad =
              audioProvider.currentTrack == null ||
              audioProvider.currentTrack!.trackId != trackId;

          if (needsTrackLoad) {
            final tracks = eventProvider.currentPlaylistTracks;
            if (tracks.isNotEmpty) {
              final index = tracks.indexWhere((t) => t.trackId == trackId);
              final startIndex = index >= 0 ? index : 0;
              await audioProvider.playPlaylist(
                tracks,
                startIndex: startIndex,
                autoPlay: false,
                sourceType: eventProvider.currentPlaylist?.type,
              );
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }

          // Seek to current position
          if (startTime != null && audioProvider.currentTrack != null) {
            final int targetSeconds = (startTime is double)
                ? startTime.round()
                : (startTime as num).toInt();
            await audioProvider.seek(Duration(seconds: targetSeconds));
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Sync play/pause state
          if (audioProvider.currentTrack != null) {
            if (isPlaying && !audioProvider.isPlaying) {
              await audioProvider.resume();
            } else if (!isPlaying && audioProvider.isPlaying) {
              await audioProvider.pause();
            }
          }

          _handlingSocketEvent = false;
          _lastKnownPlayingState = isPlaying;
        } catch (e) {
          _handlingSocketEvent = false;
          debugPrint('Error handling playback-sync: $e');
        }
      });

      // Handle time-sync: periodic server position updates for admin seek bar
      ws.on('time-sync', (data) {
        if (!mounted) return;
        try {
          final trackId = data['trackId'] as String?;
          final position = data['currentTime']; // server sends as 'currentTime'
          final duration =
              data['trackDuration']; // server sends as 'trackDuration'
          final isPlaying = data['isPlaying'] == true;

          if (trackId == null) return;

          setState(() {
            _serverTrackId = trackId;
            _serverIsPlaying = isPlaying;
            if (position != null) {
              _serverPosition = (position is double)
                  ? position
                  : (position as num).toDouble();
            }
            if (duration != null) {
              _serverDuration = (duration is double)
                  ? duration
                  : (duration as num).toDouble();
            }
            _lastTimeSyncReceived = DateTime.now();
          });
        } catch (e) {
          debugPrint('Error handling time-sync: $e');
        }
      });
    } catch (e) {
      debugPrint('Error joining event playlist room: $e');
    }
  }
  /*
  void _leaveEventPlaylistRoom() {
    try {
      // Stop listening to audio player state changes
      if (_isListeningToAudio && _audioProvider != null) {
        _audioProvider!.removeListener(_onAudioStateChanged);
        _audioProvider!.onTrackCompleted = null;
        _isListeningToAudio = false;
      }

      final ws = _wsService ?? context.read<WebSocketService>();
      ws.leaveEventPlaylist(widget.playlistId);

      // Clean up listeners (do NOT off track-added/track-removed/queue-reordered
      // as they are managed by EventProvider)
      ws.off('user-joined-playlist');
      ws.off('user-left-playlist');
      ws.off('vote-updated');
      ws.off('music-play');
      ws.off('music-pause');
      ws.off('music-stop');
      ws.off('music-seek');
      ws.off('track-skipped');
      ws.off('track-ended');
      ws.off('music-track-changed');
      ws.off('playback-sync');
      ws.off('time-sync');
      _hasJoinedRoom = false;
    } catch (e) {
      debugPrint('Error leaving event playlist room: $e');
    }
  }*/

  @override
  void dispose() {
    // Stop listening to audio player state changes
    if (_isListeningToAudio && _audioProvider != null) {
      _audioProvider!.removeListener(_onAudioStateChanged);
      _audioProvider!.onTrackCompleted = null;
      _isListeningToAudio = false;
    }

    // Clear the track-removed callback to avoid stale closures after dispose
    try {
      // ignore: use_build_context_synchronously
      final eventProvider = context.read<EventProvider>();
      if (eventProvider.onTrackRemoved != null) {
        eventProvider.onTrackRemoved = null;
      }
    } catch (_) {}

    // Safely leave room using cached websocket service (avoid context in dispose)
    try {
      if (_wsService != null) {
        _wsService!.leaveEventPlaylist(widget.playlistId);
        _wsService!.off('user-joined-playlist');
        _wsService!.off('user-left-playlist');
        _wsService!.off('vote-updated');
        _wsService!.off('music-play');
        _wsService!.off('music-pause');
        _wsService!.off('music-stop');
        _wsService!.off('music-seek');
        _wsService!.off('track-skipped');
        _wsService!.off('track-ended');
        _wsService!.off('music-track-changed');
        _wsService!.off('playback-sync');
        _wsService!.off('time-sync');
        _hasJoinedRoom = false;
      }
    } catch (e) {
      debugPrint('Error leaving event playlist room from dispose: $e');
    }

    // Unsubscribe from route observer using stored reference (safe in dispose)
    try {
      if (_modalRoute != null) {
        routeObserver.unsubscribe(this);
      }
    } catch (_) {}
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes so we can leave the socket room when the
    // screen is no longer visible (covered or popped)
    _modalRoute = ModalRoute.of(context);
    if (_modalRoute != null) {
      routeObserver.subscribe(this, _modalRoute!);
    }
    // Cache websocket service to avoid using context in dispose
    try {
      _wsService ??= context.read<WebSocketService>();
    } catch (_) {}
  }

  @override
  void didPush() {
    // Screen was just pushed — ensure we're joined
    _joinEventPlaylistRoom();
  }

  @override
  void didPopNext() {
    // Returned to this screen — re-join room if needed
    _joinEventPlaylistRoom();
  }

  @override
  void didPushNext() {
    // Another route was pushed on top (e.g., dialog or another screen)
    // We don't leave the room here because:
    // 1. Dialogs should keep the user in the room
    // 2. If it's a real navigation, dispose() will handle cleanup
    debugPrint('🎵 Route pushed on top, staying in playlist room');
  }

  Future<void> _loadPlaylist() async {
    final eventProvider = context.read<EventProvider>();
    await eventProvider.loadPlaylistDetails(widget.playlistId);

    if (!mounted) return;

    // Load voting results if this is an event (not a simple playlist)
    final playlist = eventProvider.currentPlaylist;
    if (playlist != null && playlist.type == EventType.event) {
      final votingProvider = context.read<VotingProvider>();
      await votingProvider.setCurrentEvent(widget.playlistId);

      // Set up track completion callback: server drives progression
      if (_audioProvider != null) {
        _audioProvider!.onTrackCompleted = (_) {
          debugPrint('🏁 Track completed locally: server drives progression');
        };
      }
    }
  }

  void _toggleEditMode(dynamic playlist) {
    setState(() {
      if (!_isEditMode) {
        _nameController.text = playlist.name;
        _descriptionController.text = playlist.description ?? '';
        _selectedVisibility = playlist.visibility;
        _votingInvitedOnly = playlist.licenseType == 'invited';
      }
      _isEditMode = !_isEditMode;
    });
  }

  /// Check if current user can control playback for this playlist
  /// Returns true if user is the owner OR has delegation from the owner
  bool _canControlPlayback(String? playlistCreatorId, List<Device> delegatedDevices, String? currentUserId) {
    if (currentUserId == null || playlistCreatorId == null) return false;
    
    // User is the owner
    if (currentUserId == playlistCreatorId) return true;
    
    // User has delegation from the creator (check for active delegations)
    return delegatedDevices.any((device) => 
      device.ownerId == playlistCreatorId && device.isDelegated
    );
  }

  /// Handle voting with error notification
  Future<void> _handleVote(String trackId, VoteType voteType) async {
    final votingProvider = context.read<VotingProvider>();
    final success = await votingProvider.vote(trackId, voteType);
    
    debugPrint('🗳️ Vote result - success: $success, error: ${votingProvider.error}');
    
    if (!success && mounted && votingProvider.error != null) {
      debugPrint('🚨 Showing error notification: ${votingProvider.error}');
      // Show error notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(votingProvider.error!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      
      // Clear error after displaying
      votingProvider.clearError();
    }
  }

  Future<void> _savePlaylist(EventProvider eventProvider) async {
    final success = await eventProvider.updatePlaylist(
      widget.playlistId,
      name: _nameController.text,
      description: _descriptionController.text,
      eventLicenseType: _votingInvitedOnly ? 'invited' : 'none',
      isPublic: _selectedVisibility == EventVisibility.public,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Playlist updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditMode = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${eventProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get display name for any enum (just the part after the last dot)
  String _getEnumLabel(dynamic enumValue) {
    return enumValue.toString().split('.').last;
  }

  @override
  Widget build(BuildContext context) {
    return MiniPlayerScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Playlist Details'),
          elevation: 0,
          actions: [
            Consumer2<PlaylistProvider, AuthProvider>(
              builder: (context, playlistProvider, authProvider, _) {
                final playlist = playlistProvider.currentPlaylist;
                final currentUser = authProvider.currentUser;
                final isOwner =
                    playlist != null && currentUser?.id == playlist.creatorId;
                // treat owner as admin for playlist editing permissions
                final isAdmin = isOwner;

                if (playlist != null && (isOwner || isAdmin)) {
                  return IconButton(
                    icon: Icon(_isEditMode ? Icons.close : Icons.edit),
                    onPressed: () => _toggleEditMode(playlist),
                    tooltip: _isEditMode ? 'Cancel' : 'Edit Playlist',
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: Consumer<PlaylistProvider>(
          builder: (context, playlistProvider, _) {
            if (playlistProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final playlist = playlistProvider.currentPlaylist;

            if (playlist == null) {
              return const Center(child: Text('Playlist not found'));
            }

            return _isEditMode
                ? _buildEditForm(playlistProvider, playlist)
                : _buildViewMode(playlistProvider, playlist);
          },
        ),
        floatingActionButton: _isEditMode
            ? null
            : Consumer3<EventProvider, AuthProvider, DeviceProvider>(
                builder: (context, eventProvider, authProvider, deviceProvider, _) {
                  final playlist = eventProvider.currentPlaylist;
                  final isEvent = playlist?.type == EventType.event;

                  final canControl = _canControlPlayback(
                    playlist?.creatorId,
                    deviceProvider.delegatedDevices,
                    authProvider.currentUser?.id,
                  );

                  // Hide FAB for non-admin/non-delegated users on event playlists
                  if (isEvent == true && !canControl) {
                    return const SizedBox.shrink();
                  }

                  // For playlists (type=playlist) that are public, only allow admins (creator or admin participants)
                  if (playlist != null && playlist.type == EventType.playlist) {
                    final currentUserId = authProvider.currentUser?.id;
                    final isCreator = currentUserId != null && currentUserId == playlist.creatorId;
                    final isAdminParticipant = playlist.participants?.any((p) {
                          return p.userId == currentUserId &&
                              (p.role == ParticipantRole.admin || p.role == ParticipantRole.creator);
                        }) == true;

                    final isAdmin = isCreator || isAdminParticipant;

                    if (playlist.visibility == EventVisibility.public && !isAdmin) {
                      // Public playlist — hide add for non-admin users
                      return const SizedBox.shrink();
                    }
                  }

                  return FloatingActionButton(
                    onPressed: _showAddTrackDialog,
                    tooltip: 'Add Track',
                    child: const Icon(Icons.add),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildViewMode(EventProvider eventProvider, dynamic playlist) {
    final String? headerCover = eventProvider.currentPlaylistTracks.isNotEmpty
        ? eventProvider.currentPlaylistTracks.first.coverUrl
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade700, Colors.purple.shade400],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: headerCover != null && headerCover.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                headerCover,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Icon(
                                        Icons.music_note,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                              ),
                            )
                          : const Icon(
                              Icons.music_note,
                              size: 40,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Playlist Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Playlist name
                          Text(
                            playlist.name ?? 'Untitled Playlist',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Description
                          if (playlist.description != null &&
                              playlist.description!.isNotEmpty)
                            Text(
                              playlist.description!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 12),

                          const SizedBox.shrink(),

                          // Admin playback controls (play/pause/skip/stop) for event playlists
                          // These only send commands to the server. Local playback is driven
                          // by server events (music-play, music-pause, etc.)
                          Consumer3<AuthProvider, AudioPlayerProvider, DeviceProvider>(
                            builder: (context, authProvider, audioProvider, deviceProvider, _) {
                              final currentUser = authProvider.currentUser;
                              final isEvent = playlist.type == EventType.event;
                              final canControl = _canControlPlayback(
                                playlist.creatorId,
                                deviceProvider.delegatedDevices,
                                currentUser?.id,
                              );

                              // Only show for admin/owner/delegated users of event playlists
                              if (!isEvent || !canControl) {
                                return const SizedBox.shrink();
                              }

                              // Use server state for button icons
                              final serverPlaying = _serverIsPlaying;
                              final hasServerTrack = _serverTrackId != null;
                              final hasTracks = eventProvider
                                  .currentPlaylistTracks
                                  .isNotEmpty;

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Skip button (only when server has a track playing)
                                    if (hasServerTrack)
                                      Material(
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          onTap: () {
                                            // Emit skip command to server
                                            final ws = _wsService;
                                            if (ws != null) {
                                              ws.skipTrack(widget.playlistId);
                                              debugPrint(
                                                '📤 Admin skip emitted',
                                              );
                                            }
                                          },
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.skip_next,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (hasServerTrack)
                                      const SizedBox(width: 8),
                                    // Play/Pause button — sends server command
                                    Material(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () {
                                          final ws = _wsService;
                                          if (ws == null) return;

                                          if (hasServerTrack && serverPlaying) {
                                            // Pause the server stream
                                            ws.pauseTrack(
                                              widget.playlistId,
                                              currentTime: _serverPosition,
                                            );
                                            debugPrint(
                                              '📤 Admin pause emitted',
                                            );
                                          } else if (hasServerTrack &&
                                              !serverPlaying) {
                                            // Resume the server stream
                                            ws.playTrack(
                                              widget.playlistId,
                                              trackId: _serverTrackId,
                                              startTime: _serverPosition,
                                            );
                                            debugPrint(
                                              '📤 Admin resume emitted',
                                            );
                                          } else if (hasTracks) {
                                            // Start playing from the first track
                                            final firstTrack = eventProvider
                                                .currentPlaylistTracks
                                                .first;
                                            ws.playTrack(
                                              widget.playlistId,
                                              trackId: firstTrack.trackId,
                                              startTime: 0,
                                            );
                                            debugPrint(
                                              '📤 Admin start emitted (first track)',
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Icon(
                                            (serverPlaying && hasServerTrack)
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Stop button — sends server stop command
                                    Material(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: hasServerTrack
                                            ? () {
                                                final ws = _wsService;
                                                if (ws != null) {
                                                  ws.stopStream(
                                                    widget.playlistId,
                                                  );
                                                  debugPrint(
                                                    '📤 Admin stop emitted',
                                                  );
                                                }
                                              }
                                            : null,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.stop,
                                            color: hasServerTrack
                                                ? Colors.white
                                                : Colors.white38,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Collaborator Button
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final currentUser = authProvider.currentUser;
                        final isOwner = currentUser?.id == playlist.creatorId;

                        if (isOwner) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () =>
                                    _showCollaboratorDialog(context, playlist),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    Icons.people,
                                    color: Colors.purple.shade700,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

                // Seek bar
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Consumer3<AuthProvider, AudioPlayerProvider, DeviceProvider>(
                    builder: (context, authProvider, audioProvider, deviceProvider, _) {
                      final currentUser = authProvider.currentUser;
                      final isEvent = playlist.type == EventType.event;
                      final canControl = _canControlPlayback(
                        playlist.creatorId,
                        deviceProvider.delegatedDevices,
                        currentUser?.id,
                      );

                      if (isEvent) {
                        if (!canControl) return const SizedBox.shrink();

                        if (_serverTrackId == null &&
                            !audioProvider.hasCurrentTrack) {
                          return const SizedBox.shrink();
                        }

                        final durationSeconds = _serverDuration > 0
                            ? _serverDuration
                            : (audioProvider.duration.inSeconds > 0
                                  ? audioProvider.duration.inSeconds.toDouble()
                                  : 1.0);

                        double currentPos = _serverPosition;
                        if (_serverIsPlaying && _lastTimeSyncReceived != null) {
                          final elapsed =
                              DateTime.now()
                                  .difference(_lastTimeSyncReceived!)
                                  .inMilliseconds /
                              1000.0;
                          currentPos = (_serverPosition + elapsed).clamp(
                            0.0,
                            durationSeconds,
                          );
                        }

                        final displayedValue = _isSeeking
                            ? _seekValue
                            : currentPos.clamp(0.0, durationSeconds);

                        return Column(
                          children: [
                            Slider(
                              value: displayedValue.clamp(0.0, durationSeconds),
                              min: 0.0,
                              max: durationSeconds > 0 ? durationSeconds : 1.0,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white38,
                              onChangeStart: (v) {
                                setState(() {
                                  _isSeeking = true;
                                  _seekValue = v;
                                });
                              },
                              onChanged: (v) {
                                setState(() => _seekValue = v);
                              },
                              onChangeEnd: (v) async {
                                setState(() {
                                  _isSeeking = false;
                                  _seekValue = v;
                                });
                                try {
                                  final ws =
                                      _wsService ??
                                      context.read<WebSocketService>();
                                  ws.seekTrack(
                                    widget.playlistId,
                                    v,
                                    _serverTrackId ??
                                        audioProvider.currentTrack?.trackId,
                                    _serverIsPlaying,
                                  );
                                } catch (_) {}
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  audioProvider.formatDuration(
                                    Duration(seconds: displayedValue.toInt()),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  audioProvider.formatDuration(
                                    Duration(seconds: durationSeconds.toInt()),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      // Standard playlist
                      if (!audioProvider.hasCurrentTrack) {
                        return const SizedBox.shrink();
                      }
                      if (audioProvider.sourcePlaylistId != widget.playlistId) {
                        return const SizedBox.shrink();
                      }

                      final durationSeconds =
                          audioProvider.duration.inSeconds > 0
                          ? audioProvider.duration.inSeconds.toDouble()
                          : 1.0;
                      final positionSeconds = audioProvider.position.inSeconds
                          .toDouble();
                      final displayedValue = _isSeeking
                          ? _seekValue
                          : positionSeconds.clamp(0.0, durationSeconds);

                      return Column(
                        children: [
                          Slider(
                            value: displayedValue.clamp(0.0, durationSeconds),
                            min: 0.0,
                            max: durationSeconds > 0 ? durationSeconds : 1.0,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white38,
                            onChangeStart: (v) {
                              setState(() {
                                _isSeeking = true;
                                _seekValue = v;
                              });
                            },
                            onChanged: (v) => setState(() => _seekValue = v),
                            onChangeEnd: (v) async {
                              setState(() {
                                _isSeeking = false;
                                _seekValue = v;
                              });
                              try {
                                await audioProvider.seek(
                                  Duration(seconds: v.toInt()),
                                );
                              } catch (_) {}
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                audioProvider.formatDuration(
                                  Duration(seconds: displayedValue.toInt()),
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                audioProvider.formatDuration(
                                  Duration(seconds: durationSeconds.toInt()),
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Tracks Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracks',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (eventProvider.currentPlaylistTracks.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No tracks yet',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      removeTop: true,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: eventProvider.currentPlaylistTracks.length,
                        itemBuilder: (context, index) {
                          final track =
                              eventProvider.currentPlaylistTracks[index];
                          final isEventPlaylist =
                              playlist.type == EventType.event;
                          // First track is "current" only in event playlists
                          final isFirstTrack = isEventPlaylist && index == 0;

                          return AnimatedSize(
                            key: Key('track_${track.id}'),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Consumer<AudioPlayerProvider>(
                              builder: (context, audioProvider, _) {
                                final isCurrentlyPlaying =
                                    audioProvider.currentTrack?.id == track.id;
                                // Check if playback is active for this playlist
                                final isSourcePlaylist =
                                    audioProvider.sourcePlaylistId ==
                                    widget.playlistId;
                                final isPlaybackActive =
                                    isSourcePlaylist &&
                                    audioProvider.currentTrack != null;
                                // In event playlists: first track is "current" only when playback is active
                                // When not playing, first track is unlocked (treated like any other track)
                                // In standard playlists: only the actually playing track is "current"
                                final isCurrentTrack = isEventPlaylist
                                    ? (isCurrentlyPlaying ||
                                          (isFirstTrack && isPlaybackActive))
                                    : isCurrentlyPlaying;

                                return Consumer2<AuthProvider, DeviceProvider>(
                                  builder: (context, authProvider, deviceProvider, _) {
                                    final currentUser =
                                        authProvider.currentUser;
                                    final isOwner =
                                        currentUser?.id == playlist.creatorId;
                                    // For event playlists, owner OR delegated users can delete tracks
                                    // For standard playlists, only owner can delete
                                    final canControl = _canControlPlayback(
                                      playlist.creatorId,
                                      deviceProvider.delegatedDevices,
                                      currentUser?.id,
                                    );
                                    final canDelete = isEventPlaylist ? canControl : isOwner;

                                    final trackContent = AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                      decoration:
                                          (isFirstTrack && isPlaybackActive)
                                          ? BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.purple.shade200,
                                                width: 2,
                                              ),
                                            )
                                          : null,
                                      child: GestureDetector(
                                        onTap: () async {
                                          // In event playlists, users cannot manually play tracks
                                          // Playback is controlled by the voting system and stream engine
                                          if (isEventPlaylist) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Tracks in events cannot be played manually. Use votes to influence the queue!',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                            return;
                                          }

                                          // Standard playlist: play directly.
                                          await audioProvider.playPlaylist(
                                            eventProvider
                                                .currentPlaylistTracks,
                                            startIndex: index,
                                            sourceType: playlist.type,
                                          );
                                        },
                                        child: Container(
                                          key: Key(
                                            'track_container_${track.id}',
                                          ),
                                          color: isCurrentTrack && !isFirstTrack
                                              ? Colors.purple.shade50
                                              : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              // (Drag handle removed - drag reorder disabled)

                                              // Track Cover Image
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  color: Colors.grey.shade300,
                                                  boxShadow: [
                                                    if (isCurrentTrack)
                                                      BoxShadow(
                                                        color: Colors
                                                            .purple
                                                            .shade200,
                                                        blurRadius: 4,
                                                        spreadRadius: 2,
                                                      ),
                                                  ],
                                                ),
                                                child:
                                                    track.coverUrl != null &&
                                                        track
                                                            .coverUrl!
                                                            .isNotEmpty
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        child: Image.network(
                                                          track.coverUrl!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) {
                                                                return Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .music_note,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade400,
                                                                    size: 24,
                                                                  ),
                                                                );
                                                              },
                                                        ),
                                                      )
                                                    : Center(
                                                        child: Icon(
                                                          Icons.music_note,
                                                          color: Colors
                                                              .grey
                                                              .shade400,
                                                          size: 24,
                                                        ),
                                                      ),
                                              ),

                                              // Track Title & Artist
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        track.trackTitle ??
                                                            'Unknown Track',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              isCurrentTrack
                                                              ? FontWeight.bold
                                                              : FontWeight.w500,
                                                          fontSize: 14,
                                                          color: isCurrentTrack
                                                              ? Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary
                                                              : null,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        track.trackArtist ??
                                                            'Unknown Artist',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // For first track: Show playing/paused badge when playback is active
                                              // When not playing, first track is unlocked and shows voting like other tracks
                                              if (isFirstTrack &&
                                                  playlist.type ==
                                                      EventType.event)
                                                Builder(
                                                  builder: (context) {
                                                    final isSourcePlaylist =
                                                        audioProvider
                                                            .sourcePlaylistId ==
                                                        widget.playlistId;
                                                    final isActuallyPlaying =
                                                        isSourcePlaylist &&
                                                        audioProvider.isPlaying;
                                                    final isPaused =
                                                        isSourcePlaylist &&
                                                        !audioProvider
                                                            .isPlaying &&
                                                        audioProvider
                                                                .currentTrack !=
                                                            null;

                                                    // Only show badge when track is playing or paused
                                                    // When not playing at all, show voting widget (unlocked first track)
                                                    if (isActuallyPlaying ||
                                                        isPaused) {
                                                      final String badgeText;
                                                      final IconData badgeIcon;
                                                      final Color badgeColor;

                                                      if (isActuallyPlaying) {
                                                        badgeText = 'PLAYING';
                                                        badgeIcon = Icons
                                                            .play_circle_filled;
                                                        badgeColor = Theme.of(
                                                          context,
                                                        ).colorScheme.primary;
                                                      } else {
                                                        badgeText = 'PAUSED';
                                                        badgeIcon = Icons
                                                            .pause_circle_filled;
                                                        badgeColor = Colors
                                                            .orange
                                                            .shade700;
                                                      }

                                                      return Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: badgeColor,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              badgeIcon,
                                                              color:
                                                                  Colors.white,
                                                              size: 16,
                                                            ),
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                            Text(
                                                              badgeText,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                letterSpacing:
                                                                    0.5,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }

                                                    // Not playing: show voting widget (first track is unlocked)
                                                    return Consumer<
                                                      VotingProvider
                                                    >(
                                                      builder: (context, votingProvider, _) {
                                                        final voteInfo =
                                                            votingProvider
                                                                .getTrackVoteInfo(
                                                                  track.trackId,
                                                                );
                                                        final userVote =
                                                            votingProvider
                                                                .getUserVote(
                                                                  track.trackId,
                                                                );

                                                        return CompactTrackVotingWidget(
                                                          score:
                                                              voteInfo?.score ??
                                                              0,
                                                          userVote: userVote,
                                                          isCurrentTrack:
                                                              isCurrentTrack,
                                                          isEnabled:
                                                              playlist
                                                                  .votingEnabled ??
                                                              true,
                                                          onVote: (voteType) async {
                                                            await _handleVote(
                                                              track.trackId,
                                                              voteType,
                                                            );
                                                          },
                                                          onRemoveVote: () {
                                                            votingProvider
                                                                .removeVote(
                                                                  track.trackId,
                                                                );
                                                          },
                                                        );
                                                      },
                                                    );
                                                  },
                                                )
                                              // Voting Widget (Events only, not playlists, not first track)
                                              else if (playlist.type ==
                                                      EventType.event &&
                                                  !isFirstTrack)
                                                Consumer<VotingProvider>(
                                                  builder: (context, votingProvider, _) {
                                                    final voteInfo =
                                                        votingProvider
                                                            .getTrackVoteInfo(
                                                              track.trackId,
                                                            );
                                                    final userVote =
                                                        votingProvider
                                                            .getUserVote(
                                                              track.trackId,
                                                            );

                                                    return CompactTrackVotingWidget(
                                                      score:
                                                          voteInfo?.score ?? 0,
                                                      userVote: userVote,
                                                      isCurrentTrack:
                                                          isCurrentTrack,
                                                      isEnabled:
                                                          playlist
                                                              .votingEnabled ??
                                                          true,
                                                      onVote: (voteType) async {
                                                        await _handleVote(
                                                          track.trackId,
                                                          voteType,
                                                        );
                                                      },
                                                      onRemoveVote: () {
                                                        votingProvider
                                                            .removeVote(
                                                              track.trackId,
                                                            );
                                                      },
                                                    );
                                                  },
                                                ),

                                              // Delete Button (Owner/Admin only)
                                              if (canDelete)
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.delete_outline,
                                                    size: 22,
                                                    color: Colors.red.shade400,
                                                  ),
                                                  onPressed: () async {
                                                    // Capture the State's stable context (page/scaffold) before opening dialog
                                                    final scaffoldContext =
                                                        this.context;

                                                    // Show confirmation dialog
                                                    final confirm = await showDialog<bool>(
                                                      context: scaffoldContext,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text(
                                                          'Remove Track',
                                                        ),
                                                        content: Text(
                                                          'Are you sure you want to remove "${track.trackTitle}" from the playlist?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  true,
                                                                ),
                                                            style:
                                                                TextButton.styleFrom(
                                                                  foregroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                            child: const Text(
                                                              'Remove',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirm == true &&
                                                        mounted) {
                                                      final success =
                                                          await eventProvider
                                                              .removeTrackFromPlaylist(
                                                                widget
                                                                    .playlistId,
                                                                track.trackId,
                                                              );

                                                      if (scaffoldContext
                                                          .mounted) {
                                                        ScaffoldMessenger.of(
                                                          scaffoldContext,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              success
                                                                  ? '✅ Track removed'
                                                                  : '❌ Failed to remove track',
                                                            ),
                                                            backgroundColor:
                                                                success
                                                                ? Colors.green
                                                                : Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  splashRadius: 24,
                                                )
                                              else
                                                const SizedBox(width: 48),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );

                                    return trackContent;
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(EventProvider eventProvider, dynamic playlist) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Playlist',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Basic Information
          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Playlist Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.music_note),
              helperText: 'Required',
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
              helperText: 'Optional',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          DropdownButton<EventVisibility>(
            isExpanded: true,
            value: _selectedVisibility,
            hint: const Text('Select Visibility'),
            onChanged: (EventVisibility? newValue) {
              setState(() => _selectedVisibility = newValue);
            },
            items: EventVisibility.values.map((EventVisibility visibility) {
              return DropdownMenuItem<EventVisibility>(
                value: visibility,
                child: Text(_getEnumLabel(visibility)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Playlist Stats (Read-only)
          Text(
            'Playlist Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.queue_music, color: Colors.purple.shade700),
                    const SizedBox(height: 4),
                    Text(
                      playlist.trackCount.toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tracks',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.purple.shade600,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 60, color: Colors.purple.shade200),
                Column(
                  children: [
                    Icon(Icons.people, color: Colors.purple.shade700),
                    const SizedBox(height: 4),
                    Text(
                      playlist.collaboratorCount.toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collaborators',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.purple.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons (match EventDetailsScreen visual)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () => _toggleEditMode(playlist),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: Colors.green,
                ),
                onPressed: eventProvider.isLoading
                    ? null
                    : () => _savePlaylist(eventProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Delete Button - only for owner
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final currentUser = authProvider.currentUser;
              final isOwner = currentUser?.id == playlist.creatorId;

              if (isOwner) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Playlist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _deletePlaylist(eventProvider, playlist),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }

  void _showAddTrackDialog() async {
    // Build a set of "title:::artist" keys for tracks already in the playlist
    // so the dialog can visually mark them as already added.
    final existingTrackKeys = context
        .read<EventProvider>()
        .currentPlaylistTracks
        .where((t) => t.trackTitle != null && t.trackArtist != null)
        .map((t) =>
            '${t.trackTitle!.toLowerCase().trim()}:::${t.trackArtist!.toLowerCase().trim()}')
        .toSet();

    showDialog(
      context: context,
      builder: (context) => MusicSearchDialog(
        existingTrackKeys: existingTrackKeys,
        onTrackAdded: (track) async {
          final eventProvider = context.read<EventProvider>();

          final success = await eventProvider.addTrackToPlaylist(
            widget.playlistId,
            deezerId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? '',
            albumCoverUrl: track.albumCoverUrl,
            previewUrl: track.previewUrl,
            duration: track.duration,
          );

          return success;
        },
      ),
    );
  }

  void _showCollaboratorDialog(BuildContext context, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) => CollaboratorDialog(
        playlistId: playlist.id,
        playlistName: playlist.name,
      ),
    );
  }

  Future<void> _deletePlaylist(
    EventProvider eventProvider,
    dynamic playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await eventProvider.deletePlaylist(playlist.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Playlist deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${eventProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
