import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
import 'account_linking_screen.dart';

/// Profile screen - user profile and settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
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
                      user.displayName ?? user.email,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Email
                    Text(
                      user.email,
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
                    ),
                    const Divider(),

                    // Bio
                    _buildInfoRow(
                      context,
                      'Bio',
                      user.bio ?? 'Not set',
                    ),
                    const Divider(),

                    // Location
                    _buildInfoRow(
                      context,
                      'Location',
                      user.location ?? 'Not set',
                    ),
                    const Divider(),

                    // Birth Date
                    _buildInfoRow(
                      context,
                      'Birth Date',
                      user.birthDate != null
                          ? user.birthDate!.toIso8601String().split('T')[0]
                          : 'Not set',
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
                        user.emailVerified ? Icons.check_circle : Icons.cancel,
                        color: user.emailVerified ? Colors.green : Colors.red,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Last Seen'),
                      subtitle: Text(
                        user.lastSeen?.toString().split('.')[0] ?? 'Unknown',
                      ),
                    ),
                  ],
                ),
              ),

              // Logout Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    await authProvider.logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
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
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Bio
                    TextField(
                      controller: bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    // Location
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                          borderRadius: BorderRadius.circular(4),
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
                      final authProvider = context.read<AuthProvider>();
  
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
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
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
}
