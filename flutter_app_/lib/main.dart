import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'core/providers/index.dart';
import 'core/services/index.dart';
import 'features/authentication/screens/login_screen.dart';
import 'features/authentication/screens/oauth_callback_screen.dart';
import 'features/authentication/screens/reset_password_screen.dart';
import 'features/authentication/screens/forgot_password_screen.dart';
import 'features/playlists/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🟢 App starting...');

  // Initialize app config
  AppConfig.printConfiguration();

  // Initialize services
  final secureStorage = const FlutterSecureStorage();
  final localStorage = LocalStorageService();
  await localStorage.init();

  final apiService = ApiService(
    secureStorage: SecureStorageService(secureStorage),
  );
  final authService = AuthService(
    apiService: apiService,
    secureStorage: SecureStorageService(secureStorage),
  );
  final eventService = EventService(apiService: apiService);
  final friendService = FriendService(apiService: apiService);
  final audioPlayerService = AudioPlayerService();
  final deviceService = DeviceService(apiService: apiService);
  final deviceRegistrationService = DeviceRegistrationService(
    apiService: apiService,
  );
  final webSocketService = WebSocketService();
  // PlaylistService is now an alias for EventService

  debugPrint('🟢 Services initialized');

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => apiService),
        Provider<AuthService>(create: (_) => authService),
        Provider<WebSocketService>(create: (_) => webSocketService),
        Provider<PlaylistService>(
          create: (_) => eventService,
        ), // PlaylistService is typedef for EventService
        Provider<EventService>(create: (_) => eventService),
        Provider<TrackService>(
          create: (_) => TrackService(apiService: apiService),
        ),
        Provider<InvitationService>(
          create: (_) => InvitationService(apiService: apiService),
        ),
        Provider<FriendService>(create: (_) => friendService),
        Provider<DeviceService>(create: (_) => deviceService),
        Provider<AudioPlayerService>(create: (_) => audioPlayerService),
        Provider<DeviceRegistrationService>(
          create: (_) => deviceRegistrationService,
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: authService,
            webSocketService: webSocketService,
            deviceRegistrationService: deviceRegistrationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PlaylistProvider(
            eventService: eventService,
          ), // PlaylistProvider is typedef for EventProvider
        ),
        ChangeNotifierProvider(
          create: (_) => EventProvider(eventService: eventService),
        ),
        ChangeNotifierProvider(
          create: (_) => FriendProvider(friendService: friendService),
        ),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(deviceService: deviceService),
        ),
        ChangeNotifierProvider(
          create: (_) => AudioPlayerProvider(audioService: audioPlayerService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const _InitialScreen(),
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/auth/callback': (context) => const OAuthCallbackScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle reset-password route with token parameter
        if (settings.name != null &&
            settings.name!.startsWith('/reset-password')) {
          final uri = Uri.parse('http://dummy${settings.name}');
          final token = uri.queryParameters['token'];
          if (token != null) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(token: token),
            );
          }
        }
        return null;
      },
    );
  }
}

/// Initial screen that checks authentication state
class _InitialScreen extends StatefulWidget {
  const _InitialScreen();

  @override
  State<_InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<_InitialScreen> {
  bool _isOAuthCallback = false;
  StreamSubscription<Uri>? _deepLinkSubscription;
  late AppLinks _appLinks;

  // GlobalKey to preserve HomeScreen state across rebuilds
  static final GlobalKey _homeScreenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _checkForOAuthCallback();
    _initializeAuth();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    if (kIsWeb) return; // Deep links only for mobile

    // Handle deep links when app is already running
    _deepLinkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    });

    // Handle initial deep link if app was opened via deep link
    _appLinks.getInitialAppLink().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    // Check if this is an OAuth callback (musicroom://oauth?token=...)
    if (uri.scheme == 'musicroom' && uri.host == 'oauth') {
      final params = uri.queryParameters;
      if (params.containsKey('token') || params.containsKey('success')) {
        // Process OAuth callback
        _processOAuthCallback(params);
      }
    }
    // Check if this is a password reset link (musicroom://reset-password?token=...)
    else if (uri.scheme == 'musicroom' && uri.host == 'reset-password') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        // Navigate to reset password screen with token
        Navigator.of(context).pushNamed('/reset-password?token=$token');
      }
    }
  }

  Future<void> _processOAuthCallback(Map<String, String> params) async {
    try {
      if (params.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OAuth error: ${params['error']}')),
        );
        return;
      }

      if (params.containsKey('token')) {
        final token = params['token']!;
        final refreshToken = params['refresh'];

        final authProvider = context.read<AuthProvider>();

        // Store tokens
        await authProvider.authService.secureStorage.saveToken(token);
        if (refreshToken != null) {
          await authProvider.authService.secureStorage.saveRefreshToken(
            refreshToken,
          );
        }

        // Reinitialize auth state
        await authProvider.init();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully logged in!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing login: $e')));
      }
    }
  }

  void _checkForOAuthCallback() {
    if (kIsWeb) {
      final uri = Uri.base;
      // Check if this is an OAuth callback
      // Look for success=true or token parameter
      if (uri.queryParameters.containsKey('token') ||
          uri.queryParameters.containsKey('success')) {
        setState(() {
          _isOAuthCallback = true;
        });
      }
    }
  }

  Future<void> _initializeAuth() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().init();
    });
    // final authProvider = context.read<AuthProvider>();
    // await authProvider.init();
  }

  @override
  Widget build(BuildContext context) {
    // If this is an OAuth callback, show the callback screen
    if (_isOAuthCallback) {
      // After showing the callback screen once, clear the flag
      // This will be called after the callback screen processes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOAuthCallback) {
          setState(() {
            _isOAuthCallback = false;
          });
        }
      });
      return const OAuthCallbackScreen();
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Debug mode: skip authentication
        if (AppConfig.debugSkipAuth) {
          return const HomeScreen();
        }

        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated) {
          return HomeScreen(key: _homeScreenKey);
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
