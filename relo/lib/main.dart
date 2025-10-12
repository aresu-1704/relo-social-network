import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/firebase_options.dart';
import 'package:relo/screen/default_screen.dart';
import 'package:relo/screen/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:relo/services/websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Kiểm tra trạng thái đăng nhập
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  // Nếu đã đăng nhập thì kết nối WebSocket luôn
  if (token != null && token.isNotEmpty) {
    webSocketService.connect(token);
  }
  runApp(MyApp(isLoggedIn: token != null && token.isNotEmpty));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(primarySwatch: Colors.purple);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Relo",
      theme: theme.copyWith(
        textTheme: GoogleFonts.robotoTextTheme(theme.textTheme),
      ),
      // Nếu đã đăng nhập thì vào MainScreen, ngược lại vào DefaultScreen
      home: isLoggedIn ? const MainScreen() : const DefaultScreen(),
    );
  }
}
