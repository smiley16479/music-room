import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';

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

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    final playlistProvider = context.read<PlaylistProvider>();
    await playlistProvider.loadPlaylistDetails(widget.playlistId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist Details'),
        elevation: 0,
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
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTrackDialog,
        tooltip: 'Add Track',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTrackDialog() {
    final dezerIdController = TextEditingController();
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    final albumController = TextEditingController();
    final previewUrlController = TextEditingController();
    final durationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Track to Playlist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dezerIdController,
                  decoration: const InputDecoration(
                    labelText: 'Deezer ID',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 123456789',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Track Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: artistController,
                  decoration: const InputDecoration(
                    labelText: 'Artist',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: albumController,
                  decoration: const InputDecoration(
                    labelText: 'Album',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: previewUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Preview URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration in seconds (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 180',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dezerIdController.text.isEmpty ||
                    titleController.text.isEmpty ||
                    artistController.text.isEmpty ||
                    albumController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                    ),
                  );
                  return;
                }

                final playlistProvider = context.read<PlaylistProvider>();
                int? duration;
                if (durationController.text.isNotEmpty) {
                  duration = int.tryParse(durationController.text);
                }

                final success = await playlistProvider.addTrackToPlaylist(
                  widget.playlistId,
                  deezerId: dezerIdController.text,
                  title: titleController.text,
                  artist: artistController.text,
                  album: albumController.text,
                  previewUrl: previewUrlController.text.isNotEmpty
                      ? previewUrlController.text
                      : null,
                  duration: duration,
                );

                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Track added successfully!'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${playlistProvider.error}'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
