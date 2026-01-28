import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
import 'account_linking_screen.dart';
import 'friends_screen.dart';

/// Profile screen - user profile and settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum Privacy { public, friends, private }

class SingleChoice extends StatelessWidget {
  final Privacy value;
  final ValueChanged<Privacy> onChanged;

  const SingleChoice({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: SegmentedButton<Privacy>(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
        ),
        segments: const <ButtonSegment<Privacy>>[
          ButtonSegment<Privacy>(
            value: Privacy.public,
            label: Text('Public', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment<Privacy>(
            value: Privacy.friends,
            label: Text('Friends', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment<Privacy>(
            value: Privacy.private,
            label: Text('Private', style: TextStyle(fontSize: 12)),
          ),
        ],
        selected: <Privacy>{value},
        onSelectionChanged: (Set<Privacy> newSelection) {
          onChanged(newSelection.first);
        },
        showSelectedIcon: false,
      ),
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;

        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: user.avatarUrl != null && user.avatarUrl!.startsWith('http')
                          ? ClipOval(
                              child: Image.network(
                                user.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildAvatarPlaceholder(context);
                                },
                              ),
                            )
                          : _buildAvatarPlaceholder(context),
                    ),
                    const SizedBox(height: 16),
                    // User Name
                    Text(
                      user.displayName ?? user.email ?? 'Unknown',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Email
                    if (user.email != null)
                      Text(
                        user.email!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                  ],
                ),
              ),

              // Profile Information Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    _buildInfoRow(
                      context,
                      'Display Name',
                      user.displayName ?? 'Not set',
                      user.displayNameVisibility ?? '',
                    ),
                    const Divider(),

                    // Bio
                    _buildInfoRow(
                      context,
                      'Bio',
                      user.bio ?? 'Not set',
                      user.bioVisibility ?? '',
                    ),
                    const Divider(),

                    // Location
                    _buildInfoRow(
                      context,
                      'Location',
                      user.location ?? 'Not set',
                      user.locationVisibility ?? '',
                    ),
                    const Divider(),

                    // Birth Date
                    _buildInfoRow(
                      context,
                      'Birth Date',
                      user.birthDate != null
                          ? user.birthDate!.toIso8601String().split('T')[0]
                          : 'Not set',
                      user.birthDateVisibility ?? '',
                    ),
                    const Divider(),

                    // Music Preferences
                    _buildMusicPreferencesRow(
                      context,
                      user.musicPreferences ?? [],
                      user.musicPreferenceVisibility ?? '',
                    ),
                    const SizedBox(height: 24),

                    // Edit Profile Button
                    ElevatedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                  ],
                ),
              ),

              // Friends Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Friends',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FriendsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer<FriendProvider>(
                      builder: (context, friendProvider, _) {
                        final receivedCount = friendProvider.pendingReceivedInvitations.length;
                        final sentCount = friendProvider.pendingSentInvitations.length;
                        
                        if (receivedCount == 0 && sentCount == 0) {
                          return const SizedBox.shrink();
                        }
                        
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  receivedCount > 0 && sentCount > 0
                                      ? '$receivedCount pending request${receivedCount > 1 ? 's' : ''} received • $sentCount sent'
                                      : receivedCount > 0
                                          ? '$receivedCount pending request${receivedCount > 1 ? 's' : ''} received'
                                          : '$sentCount pending request${sentCount > 1 ? 's' : ''} sent',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Connected Accounts Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Connected Accounts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AccountLinkingScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAccountTile(
                      'Google',
                      user.googleId != null,
                      Icons.g_mobiledata,
                    ),
                    const Divider(),
                    _buildAccountTile(
                      'Facebook',
                      user.facebookId != null,
                      Icons.facebook,
                    ),
                  ],
                ),
              ),

              // Settings Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Email Verified'),
                      trailing: Icon(
                        (user.emailVerified ?? false) ? Icons.check_circle : Icons.cancel,
                        color: (user.emailVerified ?? false) ? Colors.green : Colors.red,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Last Seen'),
                      subtitle: Text(
                        user.lastSeen?.toString().split('.')[0] ?? 'Unknown',
                      ),
                    ),
                    const Divider(),
                    // Change Password button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final parentCtx = context;
                        final authProvider = parentCtx.read<AuthProvider>();
                        final email = authProvider.user?.email;
                        if (email == null) return;

                        ScaffoldMessenger.of(parentCtx).showSnackBar(
                          const SnackBar(content: Text('Sending password reset email...')),
                        );

                        try {
                          await authProvider.authService.apiService.post(
                            '/auth/forgot-password',
                            body: {'email': email},
                          );

                          if (parentCtx.mounted) {
                            ScaffoldMessenger.of(parentCtx).showSnackBar(
                              SnackBar(content: Text('Password reset email sent to $email')),
                            );
                          }
                        } catch (e) {
                          if (parentCtx.mounted) {
                            ScaffoldMessenger.of(parentCtx).showSnackBar(
                              SnackBar(content: Text('Failed to send reset email: ${e.toString()}')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Change Password'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.3),
      child: Icon(
        Icons.person,
        size: 50,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, String visibility) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                visibility,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.purple,
                      fontSize: 12,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicPreferencesRow(BuildContext context, List<String> preferences, String visibility) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Music Preferences',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                visibility,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.purple,
                      fontSize: 12,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (preferences.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: preferences.map((genre) {
                return Chip(
                  label: Text(genre),
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            )
          else
            Text(
              'Not set',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(String name, bool isConnected, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(name),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isConnected ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          isConnected ? 'Connected' : 'Not Connected',
          style: TextStyle(
            color: isConnected ? Colors.green : Colors.grey,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    // Save the parent context before showing dialog
    final parentContext = context;

    final displayNameController = TextEditingController(text: user.displayName);
    final bioController = TextEditingController(text: user.bio);
    final locationController = TextEditingController(text: user.location);

    final now = DateTime.now();
    final firstDate = DateTime(now.year - 100, now.month, now.day);
    final lastDate = DateTime(now.year - 18, now.month, now.day);

    // Use user's existing DOB if available
    DateTime selectedDate = user.birthDate ?? lastDate;

    // Clamp to valid range
    if (selectedDate.isBefore(firstDate)) selectedDate = firstDate;
    if (selectedDate.isAfter(lastDate)) selectedDate = lastDate;

    final birthDateController = TextEditingController(
      text: selectedDate.toIso8601String().split('T').first,
    );

    // Visibility states
    Privacy displayNameVisibility = _parseVisibility(user.displayNameVisibility);
    Privacy bioVisibility = _parseVisibility(user.bioVisibility);
    Privacy locationVisibility = _parseVisibility(user.locationVisibility);
    Privacy birthDateVisibility = _parseVisibility(user.birthDateVisibility);
    Privacy musicPreferenceVisibility = _parseVisibility(user.musicPreferenceVisibility);

    // Music preferences
    final availableGenres = [
      'Rock', 'Pop', 'Jazz', 'Classical', 'Hip Hop', 'Rap',
      'Blues', 'Country', 'Electronic', 'Reggae', 'Metal',
      'R&B', 'Soul', 'Indie', 'Folk', 'Punk'
    ];
    Set<String> selectedGenres = user.musicPreferences?.toSet() ?? {};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display Name
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    SingleChoice(
                      value: displayNameVisibility,
                      onChanged: (value) {
                        setDialogState(() {
                          displayNameVisibility = value;
                        });
                      },
                    ),
                    // Bio
                    TextField(
                      controller: bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    SingleChoice(
                      value: bioVisibility,
                      onChanged: (value) {
                        setDialogState(() {
                          bioVisibility = value;
                        });
                      },
                    ),
                    // Location
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    SingleChoice(
                      value: locationVisibility,
                      onChanged: (value) {
                        setDialogState(() {
                          locationVisibility = value;
                        });
                      },
                    ),
                    // Birth Date
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                            birthDateController.text =
                                picked.toIso8601String().split('T').first;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              birthDateController.text.isEmpty
                                  ? 'Select birth date'
                                  : birthDateController.text,
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    SingleChoice(
                      value: birthDateVisibility,
                      onChanged: (value) {
                        setDialogState(() {
                          birthDateVisibility = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Music Preferences
                    const Text(
                      'Music Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableGenres.map((genre) {
                          final isSelected = selectedGenres.contains(genre);
                          return FilterChip(
                            label: Text(genre),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedGenres.add(genre);
                                } else {
                                  selectedGenres.remove(genre);
                                }
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                            checkmarkColor: Theme.of(context).primaryColor,
                          );
                        }).toList(),
                      ),
                    ),
                    SingleChoice(
                      value: musicPreferenceVisibility,
                      onChanged: (value) {
                        setDialogState(() {
                          musicPreferenceVisibility = value;
                        });
                      },
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
                    if (displayNameController.text.isNotEmpty) {
                      // Close dialog first to avoid navigation issues
                      Navigator.of(context).pop();
                      
                      // Use parent context for the auth provider
                      final authProvider = parentContext.read<AuthProvider>();
  
                      final success = await authProvider.updateProfile(
                        displayName: displayNameController.text.trim().isNotEmpty
                            ? displayNameController.text.trim()
                            : null,
                        bio: bioController.text.trim().isNotEmpty
                            ? bioController.text.trim()
                            : null,
                        location: locationController.text.trim().isNotEmpty
                            ? locationController.text.trim()
                            : null,
                        birthDate: birthDateController.text.trim().isNotEmpty
                            ? birthDateController.text.trim()
                            : null,
                        displayNameVisibility: _visibilityToString(displayNameVisibility),
                        bioVisibility: _visibilityToString(bioVisibility),
                        locationVisibility: _visibilityToString(locationVisibility),
                        birthDateVisibility: _visibilityToString(birthDateVisibility),
                        musicPreferences: selectedGenres.toList(),
                        musicPreferenceVisibility: _visibilityToString(musicPreferenceVisibility),
                      );
                      
                      // Show the snackbar using the parent context
                      if (parentContext.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${authProvider.error}'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Privacy _parseVisibility(String? visibility) {
    switch (visibility?.toLowerCase()) {
      case 'friends':
        return Privacy.friends;
      case 'private':
        return Privacy.private;
      default:
        return Privacy.public;
    }
  }

  String _visibilityToString(Privacy privacy) {
    switch (privacy) {
      case Privacy.public:
        return 'public';
      case Privacy.friends:
        return 'friends';
      case Privacy.private:
        return 'private';
    }
  }
}
