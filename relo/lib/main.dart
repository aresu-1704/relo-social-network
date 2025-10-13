import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/firebase_options.dart';
import 'package:relo/screen/default_screen.dart';
import 'package:relo/screen/main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize all services
  ServiceLocator.init();

  final storage = const SecureStorageService();
  final refreshToken = await storage.getRefreshToken();
  bool isLoggedIn = refreshToken != null;

  if (isLoggedIn) {
    // Attempt to fetch user data to validate and refresh the token if necessary.
    final userService = ServiceLocator.userService;
    final user = await userService.getMe();

    if (user != null) {
      // Session is valid, get the fresh token for the WebSocket connection.
      final accessToken = await storage.getAccessToken();
      if (accessToken != null) {
        webSocketService.connect(accessToken);
      }
    } else {
      // Could not validate session (e.g., offline), treat as logged out for now.
      // The connectivity service will show an offline banner.
      isLoggedIn = false;
    }
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(primarySwatch: Colors.purple);

    return MaterialApp(
      navigatorKey:
          ServiceLocator.navigatorKey, // Assign the global navigator key
      debugShowCheckedModeBanner: false,
      title: "Relo",
      theme: theme.copyWith(
        textTheme: GoogleFonts.robotoTextTheme(theme.textTheme),
      ),
      home: isLoggedIn ? const MainScreen() : const DefaultScreen(),
    );
  }
}
