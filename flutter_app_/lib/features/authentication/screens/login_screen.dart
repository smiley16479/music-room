import 'dart:io' show Platform;import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/index.dart';
import '../../../config/app_config.dart';
import 'register_screen.dart';

/// Login screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Navigate to home screen on successful login
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Login failed')),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (kIsWeb) {
      // Web: Use browser-based OAuth flow - redirect in same window
      try {
        final redirectUri = AppConfig.frontendUrl;
        final url = Uri.parse('${AppConfig.oauthBaseUrl}/auth/google')
            .replace(queryParameters: {'redirect_uri': redirectUri});
        await launchUrl(url, webOnlyWindowName: '_self');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Google Sign In: $e')),
        );
      }
    } else {
      // Mobile: Use native Google Sign-In SDK
      try {
        // For Android: use Android client ID + server client ID for backend verification
        // For iOS: pass the iOS client ID
        final GoogleSignIn googleSignIn = Platform.isAndroid 
          ? GoogleSignIn(
              clientId: AppConfig.googleAndroidClientId, // Android client ID
              serverClientId: AppConfig.googleWebClientId, // Web client ID for server verification
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

          final authProvider = context.read<AuthProvider>();
          final platform = Platform.isAndroid ? 'android' : 'ios';
          final success = await authProvider.googleSignIn(
            idToken: googleAuth.idToken ?? '',
            platform: platform,
          );

          if (!mounted) return;

          if (!success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: ${authProvider.error}')),
            );
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In failed: $e')),
        );
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    if (kIsWeb) {
      // Web: Use browser-based OAuth flow - redirect in same window
      try {
        final redirectUri = AppConfig.frontendUrl;
        final url = Uri.parse('${AppConfig.oauthBaseUrl}/auth/facebook')
            .replace(queryParameters: {'redirect_uri': redirectUri});
        await launchUrl(url, webOnlyWindowName: '_self');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Facebook Sign In: $e')),
        );
      }
    } else {
      // Mobile: Use native Facebook Login SDK
      try {
        final result = await FacebookAuth.instance.login();

        if (result.status == LoginStatus.success) {
          final accessToken = result.accessToken;
          final authProvider = context.read<AuthProvider>();
          final success = await authProvider.facebookSignIn(
            accessToken: accessToken?.tokenString ?? '',
          );

          if (!mounted) return;

          if (!success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: ${authProvider.error}')),
            );
          }
        } else if (result.status == LoginStatus.cancelled) {
          // User cancelled, do nothing
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Facebook login failed: ${result.message}')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Facebook Sign In failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Music Room',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/forgot-password');
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            authProvider.isLoading ? null : _handleLogin,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Login'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or login with',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleGoogleSignIn,
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleFacebookSignIn,
                        icon: const Icon(Icons.facebook),
                        label: const Text('Facebook'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
