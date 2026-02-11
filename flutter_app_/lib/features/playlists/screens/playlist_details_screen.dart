import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/event.dart';
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
  // Timestamp of last emitted event to prevent processing own events
  DateTime? _lastEmittedEventTime;

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
  /// When the admin toggles play/pause (e.g. via mini player), emit socket events.
  void _onAudioStateChanged() {
    if (!mounted || _handlingSocketEvent) return;

    final audioProvider = _audioProvider;
    if (audioProvider == null) return;

    // Check if user is admin/owner of an event playlist
    try {
      final eventProvider = context.read<EventProvider>();
      final authProvider = context.read<AuthProvider>();
      final playlist = eventProvider.currentPlaylist;
      if (playlist == null || playlist.type != EventType.event) return;
      final isOwner = authProvider.currentUser?.id == playlist.creatorId;
      if (!isOwner) return;
    } catch (_) {
      return;
    }

    final isPlaying = audioProvider.isPlaying;
    final trackId = audioProvider.currentTrack?.trackId;

    // Only emit when the state actually transitions
    if (_lastKnownPlayingState != null &&
        _lastKnownPlayingState != isPlaying &&
        trackId != null) {
      final ws = _wsService;
      if (ws != null) {
        // Mark that we just emitted an event to prevent processing it when it comes back
        _lastEmittedEventTime = DateTime.now();

        if (isPlaying) {
          final position = audioProvider.position.inSeconds.toDouble();
          ws.playTrack(
            widget.playlistId,
            trackId: trackId,
            startTime: position,
          );
          debugPrint(
            '📤 Admin play emitted via listener (track: $trackId, pos: $position)',
          );
        } else {
          final position = audioProvider.position.inSeconds.toDouble();
          ws.pauseTrack(widget.playlistId, currentTime: position);
          debugPrint('📤 Admin pause emitted via listener (pos: $position)');
        }
      }
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

      // Playlist event listeners
      ws.on('track-added', (data) {});

      ws.on('track-removed', (data) {});

      ws.on('vote-updated', (data) {
        if (mounted) {
          debugPrint('🗳️ Vote updated: $data');
          // VotingProvider has its own global listener, just refresh UI
          if (mounted) setState(() {});
        }
      });

      ws.on('queue-reordered', (data) {});

      ws.on('music-play', (data) async {
        if (!mounted) return;

        // Skip if this event was triggered by the current user's own action
        final controlledBy = data['controlledBy'];
        debugPrint(
          '📥 Received music-play event: controlledBy=$controlledBy, currentUserId=$_currentUserId',
        );

        // Check 1: Skip if controlledBy matches current user
        if (_currentUserId != null &&
            controlledBy != null &&
            controlledBy == _currentUserId) {
          debugPrint('▶️ Skipping own music-play event (controlledBy match)');
          return;
        }

        // Check 2: Skip if we just emitted an event (within last 500ms)
        // This catches cases where backend doesn't send controlledBy correctly
        if (_lastEmittedEventTime != null) {
          final timeSinceEmit = DateTime.now()
              .difference(_lastEmittedEventTime!)
              .inMilliseconds;
          if (timeSinceEmit < 500) {
            debugPrint(
              '▶️ Skipping music-play event - too soon after emit ($timeSinceEmit ms)',
            );
            return;
          }
        }

        try {
          final trackId = data['trackId'];
          final startTime = data['startTime'];

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
              );
              // Wait for track to be ready before seeking
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }

          // Always seek to the admin's position before resuming to stay in sync
          if (startTime != null && audioProvider.currentTrack != null) {
            final int targetSeconds = (startTime is double)
                ? startTime.round()
                : (startTime as num).toInt();
            final currentSeconds = audioProvider.position.inSeconds;
            final positionDiff = (targetSeconds - currentSeconds).abs();

            debugPrint(
              '▶️ Position check: target=$targetSeconds, current=$currentSeconds, diff=$positionDiff',
            );

            // Seek if positions differ by >= 1 second or if we just loaded a new track
            if (needsTrackLoad || positionDiff >= 1) {
              debugPrint('▶️ Seeking to $targetSeconds seconds');
              await audioProvider.seek(Duration(seconds: targetSeconds));
              if (mounted) {
                setState(() {
                  _seekValue = targetSeconds.toDouble();
                });
              }
              await Future.delayed(const Duration(milliseconds: 100));
            } else {
              debugPrint('▶️ Skipping seek - positions are close enough');
            }
          }

          // Resume playback to sync with admin
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

        // Skip if this event was triggered by the current user's own action
        final controlledBy = data['controlledBy'];
        debugPrint(
          '📥 Received music-pause event: controlledBy=$controlledBy, currentUserId=$_currentUserId',
        );

        // Check 1: Skip if controlledBy matches current user
        if (_currentUserId != null &&
            controlledBy != null &&
            controlledBy == _currentUserId) {
          debugPrint('⏸️ Skipping own music-pause event (controlledBy match)');
          return;
        }

        // Check 2: Skip if we just emitted an event (within last 500ms)
        if (_lastEmittedEventTime != null) {
          final timeSinceEmit = DateTime.now()
              .difference(_lastEmittedEventTime!)
              .inMilliseconds;
          if (timeSinceEmit < 500) {
            debugPrint(
              '⏸️ Skipping music-pause event - too soon after emit ($timeSinceEmit ms)',
            );
            return;
          }
        }

        try {
          final trackId = data['trackId'];
          final currentTime = data['currentTime'];

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
              );
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }

          // Seek to the admin's paused position to stay in sync
          if (currentTime != null && audioProvider.currentTrack != null) {
            final int targetSeconds = (currentTime is double)
                ? currentTime.round()
                : (currentTime as num).toInt();
            final currentSeconds = audioProvider.position.inSeconds;
            final positionDiff = (targetSeconds - currentSeconds).abs();

            debugPrint(
              '⏸️ Position check: target=$targetSeconds, current=$currentSeconds, diff=$positionDiff',
            );

            // Seek if positions differ by >= 1 second or if we just loaded a new track
            if (needsTrackLoad || positionDiff >= 1) {
              debugPrint('⏸️ Seeking to $targetSeconds seconds');
              await audioProvider.seek(Duration(seconds: targetSeconds));
              if (mounted) {
                setState(() {
                  _seekValue = targetSeconds.toDouble();
                });
              }
              await Future.delayed(const Duration(milliseconds: 100));
            } else {
              debugPrint('⏸️ Skipping seek - positions are close enough');
            }
          }

          // Pause playback to sync with admin
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

      // Listen for admin seek events and update local player position
      ws.on('music-seek', (data) async {
        if (!mounted) return;

        // Skip if this event was triggered by the current user's own action
        final controlledBy = data['controlledBy'];
        if (_currentUserId != null && controlledBy == _currentUserId) {
          debugPrint('⏩ Skipping own music-seek event');
          return;
        }

        try {
          final seekTime = data['seekTime'];
          final trackId = data['trackId'];
          final isPlaying = data['isPlaying'] == true;

          final audioProvider = context.read<AudioPlayerProvider>();
          final eventProvider = context.read<EventProvider>();

          _handlingSocketEvent = true;

          // Check if we need to load a track (no track loaded or different track)
          final needsTrackLoad =
              trackId != null &&
              trackId.isNotEmpty &&
              (audioProvider.currentTrack == null ||
                  audioProvider.currentTrack!.trackId != trackId);

          if (needsTrackLoad) {
            // Load the specified track
            final tracks = eventProvider.currentPlaylistTracks;
            if (tracks.isNotEmpty) {
              final index = tracks.indexWhere((t) => t.trackId == trackId);
              final startIndex = index >= 0 ? index : 0;

              // Load the track, seek to position, then set play state
              await audioProvider.playPlaylist(
                tracks,
                startIndex: startIndex,
                autoPlay: false,
              );

              // Wait for track to be ready before seeking
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }

          // Seek to the admin's position
          if (seekTime != null && audioProvider.currentTrack != null) {
            final int seconds = (seekTime is double)
                ? seekTime.round()
                : (seekTime as num).toInt();

            await audioProvider.seek(Duration(seconds: seconds));
            setState(() {
              _seekValue = seconds.toDouble();
            });

            // Give seek operation time to complete
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Sync play/pause state with admin
          if (audioProvider.currentTrack != null) {
            if (isPlaying && !audioProvider.isPlaying) {
              // Admin is playing - resume playback
              await audioProvider.resume();
            } else if (!isPlaying && audioProvider.isPlaying) {
              // Admin is paused - pause playback
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
    } catch (e) {
      debugPrint('Error joining event playlist room: $e');
    }
  }

  void _leaveEventPlaylistRoom() {
    try {
      // Stop listening to audio player state changes
      if (_isListeningToAudio && _audioProvider != null) {
        _audioProvider!.removeListener(_onAudioStateChanged);
        _isListeningToAudio = false;
      }

      final ws = _wsService ?? context.read<WebSocketService>();
      ws.leaveEventPlaylist(widget.playlistId);

      // Clean up listeners
      ws.off('user-joined-playlist');
      ws.off('user-left-playlist');
      ws.off('track-added');
      ws.off('track-removed');
      ws.off('vote-updated');
      ws.off('queue-reordered');
      ws.off('music-play');
      ws.off('music-pause');
      ws.off('music-seek');
      ws.off('track-skipped');
      _hasJoinedRoom = false;
    } catch (e) {
      debugPrint('Error leaving event playlist room: $e');
    }
  }

  @override
  void dispose() {
    // Stop listening to audio player state changes
    if (_isListeningToAudio && _audioProvider != null) {
      _audioProvider!.removeListener(_onAudioStateChanged);
      _isListeningToAudio = false;
    }

    // Safely leave room using cached websocket service (avoid context in dispose)
    try {
      if (_wsService != null) {
        _wsService!.leaveEventPlaylist(widget.playlistId);
        _wsService!.off('user-joined-playlist');
        _wsService!.off('user-left-playlist');
        _wsService!.off('track-added');
        _wsService!.off('track-removed');
        _wsService!.off('vote-updated');
        _wsService!.off('queue-reordered');
        _wsService!.off('music-play');
        _wsService!.off('music-pause');
        _wsService!.off('music-seek');
        _wsService!.off('track-skipped');
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

    // Load voting results if this is an event (not a simple playlist)
    final playlist = eventProvider.currentPlaylist;
    if (playlist != null && playlist.type == EventType.event) {
      final votingProvider = context.read<VotingProvider>();
      await votingProvider.setCurrentEvent(widget.playlistId);
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

  Future<void> _savePlaylist(EventProvider eventProvider) async {
    final success = await eventProvider.updatePlaylist(
      widget.playlistId,
      name: _nameController.text,
      description: _descriptionController.text,
      eventLicenseType: _votingInvitedOnly ? 'invited' : 'none',
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
            : FloatingActionButton(
                onPressed: _showAddTrackDialog,
                tooltip: 'Add Track',
                child: const Icon(Icons.add),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                Container(
                  width: 120,
                  height: 120,
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
                            width: 120,
                            height: 120,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.music_note,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                          ),
                        )
                      : const Icon(
                          Icons.music_note,
                          size: 60,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(width: 16),

                // Playlist Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Playlist name with admin badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              playlist.name ?? 'Untitled Playlist',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              final currentUser = authProvider.currentUser;
                              final isOwner =
                                  currentUser?.id == playlist.creatorId;
                              if (isOwner) {
                                return Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
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

                      // Seek bar for admins (only for events)
                      Consumer2<AuthProvider, AudioPlayerProvider>(
                        builder: (context, authProvider, audioProvider, _) {
                          final currentUser = authProvider.currentUser;
                          final isOwner = currentUser?.id == playlist.creatorId;
                          if (playlist.type != EventType.event) {
                            return const SizedBox.shrink();
                          }
                          // Only show seek control to admins/owners
                          if (!isOwner) return const SizedBox.shrink();

                          final durationSeconds =
                              audioProvider.duration.inSeconds > 0
                              ? audioProvider.duration.inSeconds.toDouble()
                              : 1.0;
                          final positionSeconds = audioProvider
                              .position
                              .inSeconds
                              .toDouble();

                          final displayedValue = _isSeeking
                              ? _seekValue
                              : positionSeconds.clamp(0.0, durationSeconds);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Slider(
                                value: displayedValue.clamp(
                                  0.0,
                                  durationSeconds,
                                ),
                                min: 0.0,
                                max: durationSeconds > 0
                                    ? durationSeconds
                                    : 1.0,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white38,
                                onChangeStart: isOwner
                                    ? (v) {
                                        setState(() {
                                          _isSeeking = true;
                                          _seekValue = v;
                                        });
                                      }
                                    : null,
                                onChanged: isOwner
                                    ? (v) {
                                        setState(() {
                                          _seekValue = v;
                                        });
                                      }
                                    : null,
                                onChangeEnd: isOwner
                                    ? (v) async {
                                        setState(() {
                                          _isSeeking = false;
                                          _seekValue = v;
                                        });

                                        try {
                                          // Seek locally first
                                          await audioProvider.seek(
                                            Duration(seconds: v.toInt()),
                                          );
                                        } catch (_) {}

                                        try {
                                          final ws =
                                              _wsService ??
                                              context.read<WebSocketService>();
                                          final currentTrackId = audioProvider
                                              .currentTrack
                                              ?.trackId;
                                          final isPlaying =
                                              audioProvider.isPlaying;
                                          ws.seekTrack(
                                            widget.playlistId,
                                            v,
                                            currentTrackId,
                                            isPlaying,
                                          );
                                        } catch (_) {}
                                      }
                                    : null,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      Duration(
                                        seconds: durationSeconds.toInt(),
                                      ),
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
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () =>
                              _showCollaboratorDialog(context, playlist),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.people,
                              color: Colors.purple.shade700,
                              size: 24,
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: eventProvider.currentPlaylistTracks.length,
                      itemBuilder: (context, index) {
                        final track =
                            eventProvider.currentPlaylistTracks[index];
                        // First track (index 0) is the current/next track and should not be votable
                        final isFirstTrack = index == 0;

                        return AnimatedSize(
                          key: Key('track_${track.id}'),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Consumer<AudioPlayerProvider>(
                            builder: (context, audioProvider, _) {
                              final isCurrentlyPlaying =
                                  audioProvider.currentTrack?.id == track.id;
                              // Consider a track as "current" if it's playing OR if it's the first in queue
                              final isCurrentTrack =
                                  isCurrentlyPlaying || isFirstTrack;

                              return Consumer<AuthProvider>(
                                builder: (context, authProvider, _) {
                                  final currentUser = authProvider.currentUser;
                                  final isOwner =
                                      currentUser?.id == playlist.creatorId;
                                  final canDelete = isOwner;
                                  final isMobile =
                                      MediaQuery.of(context).size.width < 600;

                                  final trackContent = AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    decoration: isFirstTrack
                                        ? BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.purple.shade200,
                                              width: 2,
                                            ),
                                          )
                                        : null,
                                    child: GestureDetector(
                                      onTap: () async {
                                        // Play this track and set the playlist.
                                        // The _onAudioStateChanged listener will
                                        // automatically emit the play-track socket
                                        // event when it detects the state transition.
                                        await audioProvider.playPlaylist(
                                          eventProvider.currentPlaylistTracks,
                                          startIndex: index,
                                        );
                                      },
                                      child: Container(
                                        key: Key('track_container_${track.id}'),
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
                                                      track.coverUrl!.isNotEmpty
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
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
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
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : null,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // For first track: Show "NOW PLAYING" badge instead of voting
                                            if (isFirstTrack &&
                                                playlist.type ==
                                                    EventType.event)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.play_circle_filled,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'NOW PLAYING',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            // Voting Widget (Events only, not playlists, not first track)
                                            else if (playlist.type ==
                                                    EventType.event &&
                                                !isFirstTrack)
                                              Consumer<VotingProvider>(
                                                builder:
                                                    (
                                                      context,
                                                      votingProvider,
                                                      _,
                                                    ) {
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
                                                        onVote: (voteType) {
                                                          votingProvider.vote(
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
                                                                    Colors.red,
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
                                                              widget.playlistId,
                                                              track.trackId,
                                                            );

                                                    if (mounted) {
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

          // Voting Settings
          CheckboxListTile(
            title: const Text('Only invited guests can vote'),
            subtitle: const Text(
              'Restrict voting to invited collaborators only',
            ),
            value: _votingInvitedOnly,
            onChanged: (bool? newValue) {
              setState(() => _votingInvitedOnly = newValue ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
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

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _toggleEditMode(playlist),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: eventProvider.isLoading
                      ? null
                      : () => _savePlaylist(eventProvider),
                ),
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
                return ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Playlist  '),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _deletePlaylist(eventProvider, playlist),
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
    showDialog(
      context: context,
      builder: (context) => MusicSearchDialog(
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
