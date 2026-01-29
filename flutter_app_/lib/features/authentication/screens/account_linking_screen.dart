import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/index.dart';
import '../../../config/app_config.dart';

/// Account Linking Screen - allows users to link Google/Facebook accounts
class AccountLinkingScreen extends StatefulWidget {
  const AccountLinkingScreen({super.key});

  @override
  State<AccountLinkingScreen> createState() => _AccountLinkingScreenState();
}

class _AccountLinkingScreenState extends State<AccountLinkingScreen> {
  bool _isLinkingGoogle = false;
  bool _isLinkingFacebook = false;

  Future<void> _linkGoogleAccount() async {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authenticated. Please log in first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLinkingGoogle = true);

    try {
      if (kIsWeb) {
        // Web: Use browser-based OAuth flow - redirect in same window
        final token = authProvider.token!;
        final redirectUri = AppConfig.frontendUrl;
        final queryParams = {'state': token, 'redirect_uri': redirectUri};

        final linkUrl = Uri.parse(
          '${AppConfig.oauthBaseUrl}/auth/google/link',
        ).replace(queryParameters: queryParams);

        await launchUrl(linkUrl, webOnlyWindowName: '_self');
      } else {
        // Mobile: Use native Google Sign-In SDK
        // For Android: don't pass clientId, use serverClientId for backend verification
        // For iOS: pass the iOS client ID
        final GoogleSignIn googleSignIn = Platform.isAndroid
            ? GoogleSignIn(
                clientId: AppConfig.googleAndroidClientId, // Android client ID
                serverClientId: AppConfig
                    .googleWebClientId, // Web client ID for server verification
                scopes: ['email', 'profile'],
              )
            : GoogleSignIn(
                clientId: AppConfig.googleClientId,
                scopes: ['email', 'profile'],
              );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          final platform = Platform.isAndroid ? 'android' : 'ios';
          final success = await authProvider.linkGoogleAccount(
            idToken: googleAuth.idToken ?? '',
            platform: platform,
          );

          if (!mounted) return;

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google account linked successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to link Google: ${authProvider.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        setState(() => _isLinkingGoogle = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error linking Google: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLinkingGoogle = false);
    }
  }

  Future<void> _linkFacebookAccount() async {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authenticated. Please log in first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLinkingFacebook = true);

    try {
      if (kIsWeb) {
        // Web: Use browser-based OAuth flow - redirect in same window
        final token = authProvider.token!;
        final redirectUri = AppConfig.frontendUrl;
        final queryParams = {'state': token, 'redirect_uri': redirectUri};

        final linkUrl = Uri.parse(
          '${AppConfig.oauthBaseUrl}/auth/facebook/link',
        ).replace(queryParameters: queryParams);

        await launchUrl(linkUrl, webOnlyWindowName: '_self');
      } else {
        // Mobile: Use native Facebook Login SDK
        final result = await FacebookAuth.instance.login();

        if (result.status == LoginStatus.success) {
          final accessToken = result.accessToken;
          final success = await authProvider.linkFacebookAccount(
            accessToken: accessToken?.tokenString ?? '',
          );

          if (!mounted) return;

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Facebook account linked successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to link Facebook: ${authProvider.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (result.status != LoginStatus.cancelled) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Facebook login failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLinkingFacebook = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error linking Facebook: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLinkingFacebook = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Accounts')),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.currentUser;

          if (user == null) {
            return const Center(child: Text('Please log in first'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Connected Accounts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Link your social accounts to sign in faster and sync your data.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Google Account
              _buildAccountCard(
                icon: Icons.g_mobiledata,
                title: 'Google',
                isLinked: user.googleId != null,
                onLink: _linkGoogleAccount,
                isLinking: _isLinkingGoogle,
              ),

              const SizedBox(height: 16),

              // Facebook Account
              _buildAccountCard(
                icon: Icons.facebook,
                title: 'Facebook',
                isLinked: user.facebookId != null,
                onLink: _linkFacebookAccount,
                isLinking: _isLinkingFacebook,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountCard({
    required IconData icon,
    required String title,
    required bool isLinked,
    required VoidCallback onLink,
    required bool isLinking,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(
          isLinked ? 'Connected' : 'Not connected',
          style: TextStyle(color: isLinked ? Colors.green : Colors.grey),
        ),
        trailing: isLinked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : isLinking
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(onPressed: onLink, child: const Text('Link')),
      ),
    );
  }
}
