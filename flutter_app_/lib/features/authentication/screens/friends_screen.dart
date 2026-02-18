import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
import '../../../core/models/index.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/websocket_service.dart';

/// Friends management screen
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final friendProvider = context.read<FriendProvider>();
    await friendProvider.refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    
    // Clean up WebSocket listeners
    final wsService = context.read<WebSocketService>();
    wsService.off('device-control-received');
    wsService.off('device-control-revoked');
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'My Friends'),
            Tab(text: 'Search'),
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildSearchTab(),
          _buildReceivedInvitationsTab(),
          _buildSentInvitationsTab(),
        ],
      ),
    );
  }

  // ==================== My Friends Tab ====================
  Widget _buildFriendsTab() {
    return Consumer<FriendProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.friends.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.friends.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'No friends yet',
            subtitle: 'Search for users and send friend requests!',
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadFriends(),
          child: ListView.builder(
            itemCount: provider.friends.length,
            itemBuilder: (context, index) {
              final friend = provider.friends[index];
              return _buildFriendTile(friend, provider);
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendTile(User friend, FriendProvider provider) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildAvatar(friend),
      title: Text(friend.displayName ?? 'Unknown'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'view') {
            _showUserProfileDialog(friend.id);
          } else if (value == 'remove') {
            _showRemoveFriendDialog(friend, provider);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.person),
                SizedBox(width: 8),
                Text('View Profile'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, color: Colors.red),
                SizedBox(width: 8),
                Text('Remove Friend', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () => _showUserProfileDialog(friend.id),
    );
  }

  void _showRemoveFriendDialog(User friend, FriendProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove ${friend.displayName ?? friend.email} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.removeFriend(friend.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Friend removed' : 'Failed to remove friend',
                    ),
                  ),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== Search Tab ====================
  Widget _buildSearchTab() {
    return Consumer<FriendProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or ID...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            provider.clearSearch();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  if (value.length >= 2) {
                    provider.searchUsers(value);
                  } else if (value.isEmpty) {
                    provider.clearSearch();
                  }
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    provider.searchUsers(value);
                  }
                },
              ),
            ),
            Expanded(child: _buildSearchResults(provider)),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(FriendProvider provider) {
    if (provider.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        title: 'Search for users',
        subtitle: 'Enter a name, email, or user ID to find people',
      );
    }

    if (provider.searchResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: 'No users found',
        subtitle: 'Try a different search term',
      );
    }

    final currentUserId = context.read<AuthProvider>().user?.id;

    return ListView.builder(
      itemCount: provider.searchResults.length,
      itemBuilder: (context, index) {
        final user = provider.searchResults[index];

        // Skip current user in results
        if (user.id == currentUserId) {
          return const SizedBox.shrink();
        }

        return _buildSearchResultTile(user, provider);
      },
    );
  }

  Widget _buildSearchResultTile(User user, FriendProvider provider) {
    final isFriend = provider.isFriend(user.id);
    final hasPendingInvitationTo = provider.hasPendingInvitationTo(user.id);
    final hasPendingInvitationFrom = provider.hasPendingInvitationFrom(user.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildAvatar(user),
      title: Text(user.displayName ?? 'Unknown'),
      trailing: _buildSearchResultAction(
        user,
        provider,
        isFriend: isFriend,
        hasPendingTo: hasPendingInvitationTo,
        hasPendingFrom: hasPendingInvitationFrom,
      ),
      onTap: () => _showUserProfileDialog(user.id),
    );
  }

  Widget _buildSearchResultAction(
    User user,
    FriendProvider provider, {
    required bool isFriend,
    required bool hasPendingTo,
    required bool hasPendingFrom,
  }) {
    if (isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Friend',
          style: TextStyle(color: Colors.green, fontSize: 12),
        ),
      );
    }

    if (hasPendingTo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(color: Colors.orange, fontSize: 12),
        ),
      );
    }

    if (hasPendingFrom) {
      return ElevatedButton(
        onPressed: () => _showAcceptFromSearchDialog(user, provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: const Text(
          'Accept',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.person_add),
      onPressed: () => _showSendInvitationDialog(user, provider),
      tooltip: 'Send friend request',
    );
  }

  void _showAcceptFromSearchDialog(User user, FriendProvider provider) {
    final invitation = provider.receivedInvitations.firstWhere(
      (i) => i.senderId == user.id && i.isPending,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept Friend Request'),
        content: Text(
          '${user.displayName ?? user.email ?? 'Unknown'} has sent you a friend request. Accept?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.acceptInvitation(invitation.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Friend request accepted!'
                          : 'Failed to accept request',
                    ),
                  ),
                );
                if (success) {
                  await provider.loadFriends();
                }
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showSendInvitationDialog(User user, FriendProvider provider) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Friend Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a friend request to ${user.displayName ?? user.email ?? 'Unknown'}?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'Add a message to your request...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.sendFriendInvitation(
                inviteeId: user.id,
                message: messageController.text.isNotEmpty
                    ? messageController.text
                    : null,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Friend request sent!'
                          : 'Failed to send request: ${provider.error}',
                    ),
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // ==================== Received Invitations Tab ====================
  Widget _buildReceivedInvitationsTab() {
    return Consumer<FriendProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.receivedInvitations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingInvitations = provider.pendingReceivedInvitations;

        if (pendingInvitations.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'Friend requests you receive will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadReceivedInvitations(),
          child: ListView.builder(
            itemCount: pendingInvitations.length,
            itemBuilder: (context, index) {
              final invitation = pendingInvitations[index];
              return _buildReceivedInvitationTile(invitation, provider);
            },
          ),
        );
      },
    );
  }

  Widget _buildReceivedInvitationTile(
    Invitation invitation,
    FriendProvider provider,
  ) {
    final inviter = invitation.inviter;
    final isEventInvitation = invitation.type == 'event';
    final isPlaylistInvitation = invitation.type == 'playlist';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(inviter),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inviter?.displayName ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isEventInvitation)
                        Text(
                          'Invited you to an event',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else if (isPlaylistInvitation)
                        Text(
                          'Invited you to collaborate on a playlist',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(invitation.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
            if (invitation.message != null &&
                invitation.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(invitation.message!),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (invitation.type == 'friend')
                  TextButton.icon(
                    icon: const Icon(Icons.person),
                    label: const Text('View Profile'),
                    onPressed: () =>
                        _showUserProfileDialog(invitation.senderId),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () =>
                      _handleDeclineInvitation(invitation, provider),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _handleAcceptInvitation(invitation, provider),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptInvitation(
    Invitation invitation,
    FriendProvider provider,
  ) async {
    final success = await provider.acceptInvitation(invitation.id);
    if (mounted) {
      final message = invitation.type == 'event'
          ? 'Event invitation accepted!'
          : invitation.type == 'playlist'
          ? 'Playlist invitation accepted!'
          : 'Friend request accepted!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? message
                : 'Failed to accept: ${provider.error ?? "Unknown error"}',
          ),
        ),
      );
      if (success) {
        await provider.loadFriends();
      }
    }
  }

  Future<void> _handleDeclineInvitation(
    Invitation invitation,
    FriendProvider provider,
  ) async {
    final success = await provider.declineInvitation(invitation.id);
    if (mounted) {
      final message = invitation.type == 'event'
          ? 'Event invitation declined'
          : invitation.type == 'playlist'
          ? 'Playlist invitation declined'
          : 'Friend request declined';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? message
                : 'Failed to decline: ${provider.error ?? "Unknown error"}',
          ),
        ),
      );
    }
  }

  // ==================== Sent Invitations Tab ====================
  Widget _buildSentInvitationsTab() {
    return Consumer<FriendProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.sentInvitations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingInvitations = provider.pendingSentInvitations;

        if (pendingInvitations.isEmpty) {
          return _buildEmptyState(
            icon: Icons.outbox_outlined,
            title: 'No pending requests',
            subtitle: 'Friend requests you send will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadSentInvitations(),
          child: ListView.builder(
            itemCount: pendingInvitations.length,
            itemBuilder: (context, index) {
              final invitation = pendingInvitations[index];
              return _buildSentInvitationTile(invitation, provider);
            },
          ),
        );
      },
    );
  }

  Widget _buildSentInvitationTile(
    Invitation invitation,
    FriendProvider provider,
  ) {
    final invitee = invitation.invitee;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(invitee),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    invitee?.displayName ?? 'Unknown User',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                ),
              ],
            ),
            if (invitation.message != null &&
                invitation.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(invitation.message!),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sent ${_formatDate(invitation.createdAt)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () =>
                      _showCancelInvitationDialog(invitation, provider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelInvitationDialog(
    Invitation invitation,
    FriendProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
          'Are you sure you want to cancel this friend request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.cancelInvitation(invitation.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Request cancelled'
                          : 'Failed to cancel request',
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== User Profile Dialog ====================
  void _showUserProfileDialog(String userId) {
    final friendProvider = context.read<FriendProvider>();
    final currentUser = context.read<AuthProvider>().user;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<User?>(
          future: friendProvider.loadUserProfile(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final user = snapshot.data;
            if (user == null) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text(
                  'Failed to load profile: ${friendProvider.error ?? "Unknown error"}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final isFriend = friendProvider.isFriend(userId);
            final isCurrentUser = currentUser?.id == userId;

            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: ClipOval(
                              child:
                                  user.avatarUrl != null &&
                                      user.avatarUrl!.startsWith('http')
                                  ? Image.network(
                                      user.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _buildAvatarIcon(),
                                    )
                                  : _buildAvatarIcon(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.displayName ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isCurrentUser) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isFriend
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isFriend ? '✓ Friend' : 'Not a friend',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Profile Details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user.email != null)
                            _buildProfileField('Email', user.email!),
                          if (user.bio != null)
                            _buildProfileField('Bio', user.bio!),
                          if (user.location != null)
                            _buildProfileField('Location', user.location!),
                          if (user.birthDate != null)
                            _buildProfileField(
                              'Birth Date',
                              user.birthDate!.toIso8601String().split('T')[0],
                            ),
                          if (user.musicPreferences != null &&
                              user.musicPreferences!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Music Preferences',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: user.musicPreferences!.map((genre) {
                                return Chip(
                                  label: Text(
                                    genre,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          ],
                          // Device Control Delegation Section (for friends)
                          if (isFriend && !isCurrentUser) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text(
                              'Delegate Your Devices',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDeviceDelegationSection(
                              dialogContext,
                              userId,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                if (!isCurrentUser &&
                    !isFriend &&
                    !friendProvider.hasPendingInvitationTo(userId))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add Friend'),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showSendInvitationDialog(user, friendProvider);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build device control delegation section
  Widget _buildDeviceDelegationSection(
    BuildContext context,
    String delegateToUserId,
  ) {
    final currentUser = context.read<AuthProvider>().user;

    return FutureBuilder<List<Device>>(
      future: _loadUserDevices(currentUser?.id ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final devices = snapshot.data ?? [];

        if (devices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No devices available to delegate',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: devices.map((device) {
            return _buildDeviceDelegationTile(device, delegateToUserId);
          }).toList(),
        );
      },
    );
  }

  /// Build a single device delegation tile
  Widget _buildDeviceDelegationTile(Device device, String delegateToUserId) {
    // Check if this device is delegated specifically to THIS user
    final isDelegated = device.delegatedToId == delegateToUserId && device.isDelegated;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDeviceIcon(device.type),
                  size: 20,
                  color: device.isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${device.type.toString().split('.').last} • ${device.isActive ? 'Active' : 'Inactive'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isDelegated) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Control delegated • ${device.delegationTimeLeftFormatted}',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isDelegated)
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text(
                        'Extend',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () =>
                          _showExtendDelegationDialog(device, delegateToUserId),
                    ),
                  ),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      isDelegated ? Icons.block : Icons.share,
                      size: 16,
                    ),
                    label: Text(
                      isDelegated ? 'Revoke' : 'Delegate',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      if (isDelegated) {
                        _revokeDeviceControl(device.id);
                      } else {
                        _showDelegateDelegateDeviceDialog(
                          device,
                          delegateToUserId,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDelegated ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Load user devices
  Future<List<Device>> _loadUserDevices(String userId) async {
    try {
      final apiService = context.read<ApiService>();
      final deviceService = DeviceService(apiService: apiService);
      return await deviceService.getUserDevices(userId);
    } catch (e) {
      debugPrint('Error loading user devices: $e');
      return [];
    }
  }

  /// Get icon for device type
  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.phone:
        return Icons.smartphone;
      case DeviceType.tablet:
        return Icons.tablet;
      case DeviceType.desktop:
        return Icons.desktop_mac;
      case DeviceType.smartSpeaker:
        return Icons.speaker;
      case DeviceType.tv:
        return Icons.tv;
      default:
        return Icons.devices;
    }
  }

  /// Show delegate device dialog
  void _showDelegateDelegateDeviceDialog(
    Device device,
    String delegateToUserId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delegate ${device.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allow your friend to control this device for:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildDurationOption(device, delegateToUserId, 1, '1 Hour'),
            _buildDurationOption(device, delegateToUserId, 8, '8 Hours'),
            _buildDurationOption(device, delegateToUserId, 24, '24 Hours'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build duration option button
  Widget _buildDurationOption(
    Device device,
    String delegateToUserId,
    int hours,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.schedule, size: 16),
        label: Text(label),
        onPressed: () {
          Navigator.pop(context);
          _delegateDevice(device.id, delegateToUserId, hours);
        },
      ),
    );
  }

  /// Delegate device control
  Future<void> _delegateDevice(
    String deviceId,
    String delegateToUserId,
    int hours,
  ) async {
    try {
      final apiService = context.read<ApiService>();
      final deviceService = DeviceService(apiService: apiService);

      final device = await deviceService.delegateControl(
        deviceId: deviceId,
        delegatedToId: delegateToUserId,
        expiresIn: Duration(hours: hours),
      );

      if (device != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Control delegated successfully')),
        );
        // Refresh the dialog by popping and reopening
        Navigator.pop(context);
        _showUserProfileDialog(delegateToUserId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delegate: $e')));
      }
    }
  }

  /// Show extend delegation dialog
  void _showExtendDelegationDialog(Device device, String delegateToUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Extend ${device.name} Control'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current time left: ${device.delegationTimeLeftFormatted}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Extend for:', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Extend 6 hours'),
            onPressed: () {
              Navigator.pop(context);
              _extendDeviceControl(device.id, 6);
            },
          ),
        ],
      ),
    );
  }

  /// Extend device control
  Future<void> _extendDeviceControl(String deviceId, int hours) async {
    try {
      final apiService = context.read<ApiService>();
      final deviceService = DeviceService(apiService: apiService);

      final device = await deviceService.extendDelegation(deviceId, hours);

      if (device != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delegation extended')));
        // Refresh the dialog
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to extend: $e')));
      }
    }
  }

  /// Revoke device control
  Future<void> _revokeDeviceControl(String deviceId) async {
    try {
      final apiService = context.read<ApiService>();
      final deviceService = DeviceService(apiService: apiService);

      final device = await deviceService.revokeControl(deviceId);

      if (device != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Control revoked')));
        // Refresh the dialog
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to revoke: $e')));
      }
    }
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // ==================== Helper Widgets ====================
  Widget _buildAvatar(User? user) {
    if (user?.avatarUrl != null && user!.avatarUrl!.startsWith('http')) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(user.avatarUrl!),
        onBackgroundImageError: (_, _) {},
        child: user.avatarUrl == null ? _buildAvatarIcon() : null,
      );
    }
    return CircleAvatar(
      radius: 24,
      child: Text(
        (user?.displayName ?? user?.email ?? '?')[0].toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAvatarIcon() {
    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
      child: Icon(
        Icons.person,
        size: 40,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
