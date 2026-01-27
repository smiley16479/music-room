import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
import '../../authentication/screens/profile_screen.dart';
import '../widgets/create_event_dialog.dart';
import 'events_screen.dart';
import 'playlist_details_screen.dart';

/// Home screen - main tab-based interface
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    print('🔵 HomeScreen.initState() - calling _loadAllEvents()');
    _loadAllEvents();
  }

  Future<void> _loadAllEvents() async {
    print('🟡 _loadAllEvents() called');
    final eventProvider = context.read<EventProvider>();
    print('🟡 EventProvider obtained');
    await eventProvider.loadMyEvents();
    print(
      '🟡 loadMyEvents() completed - Total: ${eventProvider.myEvents.length}, Playlists: ${eventProvider.myPlaylists.length}, Events: ${eventProvider.realEvents.length}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabTitles = ['Playlists', 'Events', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitles[_selectedIndex]),
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
      body: _buildContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Playlists',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildPlaylistsContent();
      case 1:
        return _buildEventsContent();
      case 2:
        return _buildProfileContent();
      default:
        return _buildPlaylistsContent();
    }
  }

  Widget _buildPlaylistsContent() {
    return Stack(
      children: [
        Consumer<EventProvider>(
          builder: (context, eventProvider, _) {
            if (eventProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filter only LISTENING_SESSION type events (playlists)
            final playlists = eventProvider.myPlaylists;

            if (playlists.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_note, size: 64),
                    const SizedBox(height: 16),
                    const Text('No playlists yet'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showCreatePlaylistDialog,
                      child: const Text('Create Playlist'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  title: Text(playlist.name),
                  subtitle: Text(
                    '${playlist.trackCount} tracks • ${playlist.collaboratorCount} collaborators',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PlaylistDetailsScreen(playlistId: playlist.id),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _showCreatePlaylistDialog,
            tooltip: 'Create Playlist',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsContent() {
    return Stack(
      children: [
        const EventsScreen(),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => showCreateEventDialog(context),
            tooltip: 'Create Event',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileContent() {
    return const ProfileScreen();
  }

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Playlist'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Playlist Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Visibility'),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(label: Text('Public'), value: true),
                            ButtonSegment(label: Text('Private'), value: false),
                          ],
                          selected: <bool>{isPublic},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              isPublic = newSelection.first;
                            });
                          },
                        ),
                      ],
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
                    if (nameController.text.isNotEmpty) {
                      final eventProvider = context.read<EventProvider>();
                      final success = await eventProvider.createEvent(
                        name: nameController.text,
                        visibility: isPublic ? 'public' : 'private',
                        type: 'playlist', // Create as playlist
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (success) {
                          // Refresh all events to show the new playlist
                          await eventProvider.loadMyEvents();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Playlist created successfully!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${eventProvider.error}'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
