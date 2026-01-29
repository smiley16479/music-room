import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/index.dart';
import '../../../core/providers/index.dart';
import 'invite_friends_dialog.dart';

/// Dialog to manage collaborators of a playlist
class CollaboratorDialog extends StatefulWidget {
  final String playlistId;
  final String playlistName;

  const CollaboratorDialog({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<CollaboratorDialog> createState() => _CollaboratorDialogState();
}

class _CollaboratorDialogState extends State<CollaboratorDialog> {
  bool _isLoading = true;
  Event? _playlist;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final eventProvider = context.read<EventProvider>();
      await eventProvider.loadPlaylistDetails(widget.playlistId);
      
      if (mounted) {
        setState(() {
          _playlist = eventProvider.currentPlaylist;
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

  void _showInviteFriendsDialog() {
    showDialog(
      context: context,
      builder: (context) => InviteFriendsDialog(
        eventId: widget.playlistId,
        eventName: widget.playlistName,
        isPlaylist: true,
      ),
    ).then((_) {
      // Reload playlist after inviting friends
      _loadPlaylist();
    });
  }

  Future<void> _removeParticipant(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text('Are you sure you want to remove $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final eventProvider = context.read<EventProvider>();
      final success = await eventProvider.removeParticipant(widget.playlistId, userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '✅ Collaborator removed' : '❌ Failed to remove collaborator',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        
        if (success) {
          _loadPlaylist();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Collaborators',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: $_error',
                              style: TextStyle(color: Colors.red.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _playlist == null
                          ? const Center(child: Text('Playlist not found'))
                          : _buildCollaboratorsList(),
            ),

            // Add Friends Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Friends'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _showInviteFriendsDialog,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollaboratorsList() {
    final participants = _playlist?.participants ?? [];
    final currentUser = context.read<AuthProvider>().currentUser;
    final isOwner = currentUser?.id == _playlist?.creatorId;

    if (participants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No collaborators yet\nAdd friends to collaborate on this playlist',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final user = participant.user;
        final isCurrentUser = user?.id == currentUser?.id;
        final isCreator = user?.id == _playlist?.creatorId;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: user?.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        user!.avatarUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.person, color: Colors.purple.shade700),
                      ),
                    )
                  : Icon(Icons.person, color: Colors.purple.shade700),
            ),
            title: Text(
              user?.displayName ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              isCreator
                  ? 'Owner'
                  : participant.role == ParticipantRole.admin
                      ? 'Admin'
                      : 'Collaborator',
              style: TextStyle(
                color: isCreator
                    ? Colors.purple.shade700
                    : participant.role == ParticipantRole.admin
                        ? Colors.blue.shade700
                        : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: !isCreator && (isOwner || isCurrentUser)
                ? IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                    onPressed: () => _removeParticipant(
                      user?.id ?? '',
                      user?.displayName ?? 'this user',
                    ),
                    tooltip: isCurrentUser ? 'Leave playlist' : 'Remove collaborator',
                  )
                : null,
          ),
        );
      },
    );
  }
}
