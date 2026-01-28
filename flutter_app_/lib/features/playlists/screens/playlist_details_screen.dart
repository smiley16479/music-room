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
  late EventVisibility? _selectedVisibility;

  // Playlist settings
  late bool _votingInvitedOnly;

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
  }

  void _toggleEditMode(dynamic playlist) {
    setState(() {
      if (!_isEditMode) {
        _nameController.text = playlist.name;
        _descriptionController.text = playlist.description ?? '';
        _selectedVisibility = playlist.visibility;
        _votingInvitedOnly = playlist.licenseType == EventLicenseType.invited;
      }
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _savePlaylist(EventProvider eventProvider) async {
    final success = await eventProvider.updatePlaylist(
      widget.playlistId,
      name: _nameController.text,
      description: _descriptionController.text,
      eventLicenseType: _votingInvitedOnly
          ? EventLicenseType.invited.name
          : EventLicenseType.none.name,
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
    return PopScope(
      canPop: !_isEditMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isEditMode) {
          // Close edit mode instead of popping
          setState(() {
            _isEditMode = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Playlists'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                final authProvider = context.read<AuthProvider>();
                await authProvider.logout();
              },
            ),
          ],
        ),
        body: Consumer<EventProvider>(
          builder: (context, eventProvider, _) {
            if (eventProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final playlist = eventProvider.currentPlaylist;

            if (playlist == null) {
              return const Center(child: Text('Playlist not found'));
            }

            return _isEditMode
                ? _buildEditForm(eventProvider, playlist)
                : _buildViewMode(eventProvider, playlist);
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

                // Invite Friends Button - only visible for private playlists if user is owner
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final currentUser = authProvider.currentUser;
                    final isOwner = currentUser?.id == playlist.creatorId;
                    final isPrivate =
                        playlist.visibility == EventVisibility.private;

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
                            onPressed: () =>
                                _showInviteFriendsDialog(context, playlist),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 8),
                if (playlist.description != null)
                  Text(
                    playlist.description!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                const SizedBox(height: 16),
                // Edit Button
                ElevatedButton.icon(
                  onPressed: () => _toggleEditMode(playlist),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Playlist'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tracks',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          playlist.collaboratorCount.toString(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Collaborators',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
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
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: eventProvider.currentPlaylistTracks.length,
                    itemBuilder: (context, index) {
                      final track = eventProvider.currentPlaylistTracks[index];
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
          const SizedBox(height: 16),

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
      final eventProvider = context.read<EventProvider>();

      final success = await eventProvider.addTrackToPlaylist(
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
              content: Text('❌ Error: ${eventProvider.error}'),
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
