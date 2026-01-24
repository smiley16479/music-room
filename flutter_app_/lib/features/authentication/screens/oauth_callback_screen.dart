import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';

/// OAuth Callback Screen - handles OAuth redirects from backend
class OAuthCallbackScreen extends StatefulWidget {
  const OAuthCallbackScreen({super.key});

  @override
  State<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends State<OAuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    if (!kIsWeb) {
      // Not on web, shouldn't be here
      _navigateToLogin();
      return;
    }

    // Get the current URL parameters
    final uri = Uri.base;
    final params = uri.queryParameters;

    if (params.containsKey('error')) {
      // OAuth error
      _showError(params['error'] ?? 'Unknown error');
      return;
    }

    if (params.containsKey('token')) {
      // Successful OAuth login
      try {
        final token = params['token']!;
        final refreshToken = params['refresh'];

        final authProvider = context.read<AuthProvider>();
        
        // Store tokens manually (since we got them from URL)
        await authProvider.authService.secureStorage.saveToken(token);
        if (refreshToken != null) {
          await authProvider.authService.secureStorage.saveRefreshToken(refreshToken);
        }

        // Reload the user - this will trigger a rebuild of _InitialScreen
        await authProvider.init();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully logged in!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Wait a moment for the snackbar
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        // Instead of popping, reload the page to clear URL params and show proper screen
        // This works better on web
        if (kIsWeb) {
          // Clear URL and reload - this is web-specific
          // The _InitialScreen will rebuild with isAuthenticated = true
          Navigator.of(context).pushReplacementNamed('/') ??
              Navigator.of(context).pop();
        }
      } catch (e) {
        _showError('Failed to process login: $e');
      }
    } else if (params.containsKey('success')) {
      // Success but no direct token (for account linking)
      final authProvider = context.read<AuthProvider>();
      await authProvider.init();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account linked successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // For account linking, go back instead of home
      // This should return to the profile/settings page
      Navigator.of(context).pop();
    } else {
      _showError('Invalid callback parameters');
    }
  }

  void _showError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login failed: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );

    // Navigate back to login
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _navigateToLogin();
      }
    });
  }

  void _navigateToLogin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing login...'),
          ],
        ),
      ),
    );
  }
}
