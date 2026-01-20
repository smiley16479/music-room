import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/authentication_manager.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: Consumer<AuthenticationManager>(
        builder: (context, authManager, _) {
          final user = authManager.currentUser;

          if (user == null) {
            return const Center(
              child: Text('No user data'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Center(
                          child: Text(
                            user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Account Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  label: 'Email',
                  value: user.email,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  context,
                  label: 'Member Since',
                  value: user.createdAt.toString().split(' ')[0],
                ),
                const SizedBox(height: 40),
                Text(
                  'Connected Accounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (user.googleId != null)
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Google'),
                    subtitle: const Text('Connected'),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Google'),
                    subtitle: const Text('Not connected'),
                  ),
                const SizedBox(height: 12),
                if (user.facebookId != null)
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Facebook'),
                    subtitle: const Text('Connected'),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Facebook'),
                    subtitle: const Text('Not connected'),
                  ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => _handleSignOut(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _handleSignOut(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await context.read<AuthenticationManager>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
