import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/authentication_manager.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Room'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
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
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Playlists',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Devices',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildPlaylistsContent();
      case 2:
        return _buildEventsContent();
      case 3:
        return _buildDevicesContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Music Room',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Create playlists, manage events, and collaborate with friends on music',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_play,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Your Playlists',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Playlists will appear here'),
        ],
      ),
    );
  }

  Widget _buildEventsContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Upcoming Events',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('No upcoming events'),
        ],
      ),
    );
  }

  Widget _buildDevicesContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Your Devices',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('No connected devices'),
        ],
      ),
    );
  }
}
