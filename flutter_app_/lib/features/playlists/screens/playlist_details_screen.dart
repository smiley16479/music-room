import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
import '../../../core/models/track_search_result.dart';
import '../../../core/models/event.dart';
import '../widgets/music_search_dialog.dart';
import '../widgets/invite_friends_dialog.dart';

/// Playlist Details screen
class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlistId,
  });

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

// MARK: - PlaylistDetailsScreen
class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  bool _isEditMode = false;
  
  // Text Controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadPlaylist();
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    final playlistProvider = context.read<PlaylistProvider>();
    await playlistProvider.loadPlaylistDetails(widget.playlistId);
  }

  void _toggleEditMode(dynamic playlist) {
    setState(() {
      if (!_isEditMode) {
        _nameController.text = playlist.name;
        _descriptionController.text = playlist.description ?? '';
      }
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _savePlaylist(PlaylistProvider playlistProvider) async {
    final success = await playlistProvider.updatePlaylist(
      widget.playlistId,
      name: _nameController.text,
      description: _descriptionController.text,
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
        // Reload playlist details to reflect changes
        await _loadPlaylist();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${playlistProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist Details'),
        elevation: 0,
        actions: [
          Consumer<PlaylistProvider>(
            builder: (context, playlistProvider, _) {
              final playlist = playlistProvider.currentPlaylist;
              if (playlist != null) {
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
    );
  }

  Widget _buildViewMode(PlaylistProvider playlistProvider, dynamic playlist) {
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
                      colors: [
                        Colors.purple.shade700,
                        Colors.purple.shade400,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        playlist.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (playlist.description != null)
                        Text(
                          playlist.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                playlist.trackCount.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tracks',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                playlist.collaboratorCount.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Collaborators',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tracks Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      if (playlistProvider.currentPlaylistTracks.isEmpty)
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              playlistProvider.currentPlaylistTracks.length,
                          itemBuilder: (context, index) {
                            final track =
                                playlistProvider.currentPlaylistTracks[index];
                            return ListTile(
                              leading: Text(
                                (index + 1).toString(),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              title: Text(track.trackTitle ?? 'Unknown Track'),
                              subtitle: Text(track.trackArtist ?? 'Unknown Artist'),
                              trailing: const Icon(Icons.play_arrow),
                              onTap: () {
                                // TODO: Play track
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
                
                // Invite Friends Button - only visible for private playlists if user is owner
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final currentUser = authProvider.currentUser;
                    final isOwner = currentUser?.id == playlist.creatorId;
                    final isPrivate = playlist.visibility == EventVisibility.private;
                    
                    if (isOwner && isPrivate) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add),
                            label: const Text('Invite Friends'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showInviteFriendsDialog(context, playlist),
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
          );
  }

  Widget _buildEditForm(PlaylistProvider playlistProvider, dynamic playlist) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Playlist',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.purple.shade200,
                ),
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
                  onPressed: playlistProvider.isLoading
                      ? null
                      : () => _savePlaylist(playlistProvider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTrackDialog() async {
    final result = await showDialog<TrackSearchResult>(
      context: context,
      builder: (context) => const MusicSearchDialog(),
    );

    if (result != null && mounted) {
      final playlistProvider = context.read<PlaylistProvider>();
      
      final success = await playlistProvider.addTrackToPlaylist(
        widget.playlistId,
        deezerId: result.id,
        title: result.title,
        artist: result.artist,
        album: result.album ?? '',
        albumCoverUrl: result.albumCoverUrl,
        previewUrl: result.previewUrl,
        duration: result.duration,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result.title} added to playlist'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${playlistProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showInviteFriendsDialog(BuildContext context, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) => InviteFriendsDialog(
        eventId: playlist.id,
        eventName: playlist.name,
        isPlaylist: true,
      ),
    );
  }
}
