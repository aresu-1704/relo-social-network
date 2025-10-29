import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/firebase_options.dart';
import 'package:relo/screen/main_screen.dart' show MainScreen;
import 'package:firebase_core/firebase_core.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:relo/screen/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:relo/providers/notification_provider.dart';
import 'package:relo/providers/message_provider.dart';
import 'package:relo/services/app_notification_service.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Setup Firebase background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize all services
  ServiceLocator.init();

  // Initialize notification service
  final notificationService = AppNotificationService();
  await notificationService.initialize();

  // Setup notification callbacks
  _setupNotificationCallbacks(notificationService);

  // Set up WebSocket auth error handler
  webSocketService.setAuthErrorHandler(() async {
    final context = ServiceLocator.navigatorKey.currentContext;

    if (context == null) return;

    // Hiển thị BottomSheet thông báo
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Phiên đăng nhập hết hạn 🥺',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7A2FC0),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Bạn cần đăng nhập lại',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Đóng bottom sheet
                    // Chuyển sang màn hình Login
                    ServiceLocator.navigatorKey.currentState
                        ?.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7A2FC0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Đồng ý',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  });

  final storage = const SecureStorageService();
  final refreshToken = await storage.getRefreshToken();
  bool isLoggedIn = refreshToken != null;

  if (isLoggedIn) {
    // Attempt to fetch user data to validate and refresh the token if necessary.
    final userService = ServiceLocator.userService;
    final user = await userService.getMe();

    if (user != null) {
      // Session is valid, connect the WebSocket.
      // The service will handle getting the token internally.
      webSocketService.connect();
    } else {
      // Could not validate session (e.g., offline), treat as logged out for now.
      // The connectivity service will show an offline banner.
      isLoggedIn = false;
    }
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

/// Setup notification callbacks để xử lý tap và reply
void _setupNotificationCallbacks(AppNotificationService notificationService) {
  // Callback khi tap vào notification
  notificationService.setOnNotificationTapped((String conversationId) async {
    print(
      "📱 Notification tapped, navigating to conversation: $conversationId",
    );

    // Đợi một chút để đảm bảo app đã sẵn sàng
    await Future.delayed(const Duration(milliseconds: 300));

    final navigator = ServiceLocator.navigatorKey.currentState;
    if (navigator == null) {
      // Retry sau 1 giây
      Future.delayed(const Duration(seconds: 1), () {
        final retryNavigator = ServiceLocator.navigatorKey.currentState;
        if (retryNavigator != null) {
          _navigateToChatScreen(conversationId, retryNavigator);
        }
      });
      return;
    }

    _navigateToChatScreen(conversationId, navigator);
  });

  // Setup reply callback
  _setupNotificationCallbacksContinued(notificationService);
}

/// Helper function để navigate tới ChatScreen
void _navigateToChatScreen(String conversationId, NavigatorState navigator) {
  // Đơn giản: chỉ cần navigate tới ChatScreen
  // ChatScreen sẽ tự load conversation và hiển thị
  navigator.push(
    MaterialPageRoute(
      builder: (context) => ChatScreen(
        conversationId: conversationId,
        memberIds: const [], // Sẽ được load trong ChatScreen
        isGroup: false, // Sẽ được xác định trong ChatScreen
      ),
    ),
  );
}

/// Setup notification callbacks để xử lý tap và reply (continued)
void _setupNotificationCallbacksContinued(
  AppNotificationService notificationService,
) {
  // Callback khi reply từ notification
  notificationService.setOnNotificationReply((
    String conversationId,
    String messageText,
  ) async {
    try {
      // Lấy senderId từ secure storage
      final storage = const SecureStorageService();
      final senderId = await storage.getUserId();

      if (senderId == null) {
        print("❌ Cannot send reply: User not logged in");
        return;
      }

      // Gửi tin nhắn reply qua API
      final messageService = ServiceLocator.messageService;

      await messageService.sendMessage(conversationId, {
        'type': 'text',
        'text': messageText,
      }, senderId);

      print("✅ Reply sent: $messageText to conversation: $conversationId");
    } catch (e) {
      print("❌ Error sending reply: $e");
    }
  });
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Khi app trở lại foreground
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed - checking WebSocket connection...');

      // Delay một chút để đảm bảo app đã sẵn sàng
      Future.delayed(const Duration(milliseconds: 1000), () async {
        // Kiểm tra nếu user đã đăng nhập
        const storage = SecureStorageService();
        final refreshToken = await storage.getRefreshToken();
        if (refreshToken != null) {
          // Chỉ reconnect nếu thực sự disconnected
          // Tránh reconnect liên tục
          if (!webSocketService.isConnected) {
            print('🔄 WebSocket disconnected - attempting reconnect once...');
            try {
              // Chỉ gọi connect một lần, không reconnect liên tục
              await webSocketService.connect();
            } catch (e) {
              print('❌ Error reconnecting WebSocket: $e');
              // Không làm gì, để tránh vòng lặp reconnect
            }
          } else {
            print('✅ WebSocket still connected');
          }
        }
      });
    } else if (state == AppLifecycleState.paused) {
      print('📱 App paused - WebSocket will remain connected');
      // Không disconnect WebSocket khi app vào background
      // Để server tự disconnect sau một thời gian, sau đó reconnect khi app quay lại
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(primarySwatch: Colors.purple);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
      ],
      child: MaterialApp(
        navigatorKey:
            ServiceLocator.navigatorKey, // Assign the global navigator key
        debugShowCheckedModeBanner: false,
        title: "Relo",
        theme: theme.copyWith(
          textTheme: GoogleFonts.poppinsTextTheme(theme.textTheme),
        ),
        home: widget.isLoggedIn ? const MainScreen() : const LoginScreen(),
      ),
    );
  }
}
