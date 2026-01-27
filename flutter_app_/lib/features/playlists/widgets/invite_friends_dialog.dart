import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/index.dart';
import '../../../core/providers/index.dart';

/// Dialog to invite friends to an event or playlist
class InviteFriendsDialog extends StatefulWidget {
  final String eventId;
  final String eventName;
  final bool isPlaylist;

  const InviteFriendsDialog({
    super.key,
    required this.eventId,
    required this.eventName,
    this.isPlaylist = false,
  });

  @override
  State<InviteFriendsDialog> createState() => _InviteFriendsDialogState();
}

class _InviteFriendsDialogState extends State<InviteFriendsDialog> {
  List<User> _friends = [];
  Set<String> _selectedFriendIds = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final friendProvider = context.read<FriendProvider>();
      await friendProvider.loadFriends();
      
      if (mounted) {
        setState(() {
          _friends = friendProvider.friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<User> get _filteredFriends {
    if (_searchQuery.isEmpty) {
      return _friends;
    }
    return _friends.where((friend) {
      final name = friend.displayName?.toLowerCase() ?? '';
      final email = friend.email?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  Future<void> _sendInvitations() async {
    if (_selectedFriendIds.isEmpty) {
      return;
    }

    try {
      final eventProvider = context.read<EventProvider>();
      
      // Use the invitation system (for private events)
      // This sends invitations instead of directly adding as participants
      final success = await eventProvider.inviteUsers(
        widget.eventId,
        _selectedFriendIds.toList(),
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully invited ${_selectedFriendIds.length} friend${_selectedFriendIds.length > 1 ? 's' : ''}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send invitations: ${eventProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isPlaylist ? Icons.playlist_add : Icons.event,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Friends',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'to ${widget.eventName}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Friends list
            Expanded(
              child: _buildFriendsList(),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedFriendIds.length} selected',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _selectedFriendIds.isEmpty
                            ? null
                            : _sendInvitations,
                        icon: const Icon(Icons.send),
                        label: const Text('Invite'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load friends',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFriends,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredFriends = _filteredFriends;

    if (filteredFriends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.people_outline
                  : Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No friends yet'
                  : 'No friends found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Add friends to invite them'
                  : 'Try a different search',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        final isSelected = _selectedFriendIds.contains(friend.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => _toggleFriend(friend.id),
          title: Text(friend.displayName ?? 'Unknown'),
          subtitle: friend.email != null ? Text(friend.email!) : null,
          secondary: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
            child: Text(
              (friend.displayName ?? 'U')[0].toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
