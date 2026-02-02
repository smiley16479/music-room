import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/index.dart';
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
class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  bool _isEditMode = false;

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
    _loadPlaylist();
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _selectedVisibility = null;
    _votingInvitedOnly = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: eventProvider.currentPlaylistTracks.length,
                      // Add animation for reordering
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final double elevation = Tween<double>(
                              begin: 0,
                              end: 6,
                            ).evaluate(animation);
                            final double scale = Tween<double>(
                              begin: 1.0,
                              end: 1.02,
                            ).evaluate(animation);
                            return Transform.scale(
                              scale: scale,
                              child: Material(
                                elevation: elevation,
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.transparent,
                                child: child,
                              ),
                            );
                          },
                          child: child,
                        );
                      },
                      onReorder: (oldIndex, newIndex) async {
                        // Reorder locally first
                        eventProvider.reorderTrack(oldIndex, newIndex);

                        // Build the new order as a list of playlist-track IDs
                        final newOrder = eventProvider.currentPlaylistTracks
                            .map((t) => t.id)
                            .toList();

                        // Persist the order to backend
                        final success = await eventProvider.persistReorder(
                          playlist.id,
                          newOrder,
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? '✅ Tracks reordered'
                                    : '❌ Failed to save track order',
                              ),
                              backgroundColor: success
                                  ? Colors.green
                                  : Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );

                          if (!success) {
                            // On failure, reload playlist to restore server state
                            await eventProvider.loadPlaylistDetails(
                              widget.playlistId,
                            );
                          }
                        }
                      },
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
                                    margin: isFirstTrack
                                        ? const EdgeInsets.only(bottom: 16)
                                        : EdgeInsets.zero,
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
                                      onTap: () {
                                        // Play this track and set the playlist
                                        audioProvider.playPlaylist(
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
                                            // Drag Handle (Owner only) - hidden on mobile and for first track
                                            if (isOwner &&
                                                !isMobile &&
                                                !isFirstTrack)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: Icon(
                                                  Icons.drag_handle,
                                                  color: Colors.grey.shade400,
                                                  size: 24,
                                                ),
                                              ),

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

                                  // Wrap entire container with appropriate reorder listener for owners
                                  if (isOwner && !isFirstTrack) {
                                    if (isMobile) {
                                      // On mobile, require long-press to start reordering
                                      return ReorderableDelayedDragStartListener(
                                        index: index,
                                        child: trackContent,
                                      );
                                    } else {
                                      // Desktop/tablet: immediate drag handle
                                      return ReorderableDragStartListener(
                                        index: index,
                                        child: trackContent,
                                      );
                                    }
                                  } else {
                                    return trackContent;
                                  }
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
