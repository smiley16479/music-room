import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/authentication_manager.dart';
import 'core/theme/theme_manager.dart';
import 'features/authentication/views/welcome_view.dart';
import 'features/authentication/views/sign_in_view.dart';
import 'features/authentication/views/sign_up_view.dart';
import 'features/authentication/views/forgot_password_view.dart';
import 'features/home/views/home_view.dart';
import 'features/profile/views/profile_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeManager()),
        ChangeNotifierProvider(
          create: (_) => AuthenticationManager()..initialize(),
        ),
      ],
      child: Consumer2<ThemeManager, AuthenticationManager>(
        builder: (context, themeManager, authManager, _) {
          return MaterialApp(
            title: 'Music Room',
            theme: themeManager.themeData,
            home: authManager.isLoading
              ? const SplashScreen()
              : (authManager.isAuthenticated ? const HomeView() : const WelcomeView()),
            routes: {
              '/': (_) => authManager.isAuthenticated ? const HomeView() : const WelcomeView(),
              '/welcome': (_) => const WelcomeView(),
              '/sign-in': (_) => const SignInView(),
              '/sign-up': (_) => const SignUpView(),
              '/forgot-password': (_) => const ForgotPasswordView(),
              '/home': (_) => const HomeView(),
              '/profile': (_) => const ProfileView(),
            },
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Music Room',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
