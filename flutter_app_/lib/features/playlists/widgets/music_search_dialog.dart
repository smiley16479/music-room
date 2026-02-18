import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/track_search_result.dart';
import '../../../core/services/music_service.dart';
import '../../../core/services/api_service.dart';

/// Music search dialog with live search
class MusicSearchDialog extends StatefulWidget {
  final Future<bool> Function(TrackSearchResult track)? onTrackAdded;

  /// Set of "title:::artist" keys (lowercase) for tracks already in the playlist.
  /// Used to visually indicate duplicates without blocking the user.
  final Set<String> existingTrackKeys;

  const MusicSearchDialog({
    super.key,
    this.onTrackAdded,
    this.existingTrackKeys = const {},
  });

  @override
  State<MusicSearchDialog> createState() => _MusicSearchDialogState();
}

class _MusicSearchDialogState extends State<MusicSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<TrackSearchResult> _searchResults = [];
  bool _isSearching = false;

  /// Deezer IDs of tracks added during this dialog session.
  final Set<String> _addedInSession = {};

  late MusicService _musicService;

  @override
  void initState() {
    super.initState();
    final apiService = context.read<ApiService>();
    _musicService = MusicService(apiService: apiService);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search on Deezer
      final results = await _musicService.searchDeezer(query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.music_note, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Add Track',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info text
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Searching Deezer music library',
                style: TextStyle(color: Colors.grey),
              ),
            ),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a song...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _performSearch(value);
                  }
                });
              },
              onSubmitted: _performSearch,
            ),
            const SizedBox(height: 16),

            // Results
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for music',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        return _buildTrackTile(track);
      },
    );
  }

  Widget _buildTrackTile(TrackSearchResult track) {
    final trackKey =
        '${track.title.toLowerCase().trim()}:::${track.artist.toLowerCase().trim()}';
    final isAlreadyAdded = widget.existingTrackKeys.contains(trackKey) ||
        _addedInSession.contains(track.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: track.albumCoverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  track.albumCoverUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
                  ),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.music_note),
              ),
        title: Text(
          track.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (track.album != null)
              Text(
                track.album!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Icon(
                  track.source == 'spotify' ? Icons.music_note : Icons.library_music,
                  size: 12,
                  color: track.source == 'spotify' ? Colors.green : Colors.purple,
                ),
                const SizedBox(width: 4),
                Text(
                  track.source.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: track.source == 'spotify' ? Colors.green : Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (track.duration != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${track.duration! ~/ 60}:${(track.duration! % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isAlreadyAdded
            ? Tooltip(
                message: 'Already in playlist',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 28,
                  ),
                ),
              )
            : widget.onTrackAdded != null
                ? IconButton(
                    onPressed: () async {
                      final success = await widget.onTrackAdded!(track);
                      if (success && mounted) {
                        setState(() {
                          _addedInSession.add(track.id);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ ${track.title} added to playlist'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_circle, size: 28),
                    color: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  )
                : IconButton(
                    onPressed: () => Navigator.pop(context, track),
                    icon: const Icon(Icons.add_circle, size: 28),
                    color: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
        isThreeLine: true,
      ),
    );
  }
}
