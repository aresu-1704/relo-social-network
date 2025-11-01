import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/firebase_options.dart';
import 'package:relo/screen/main_screen.dart' show MainScreen;
import 'package:firebase_core/firebase_core.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/screen/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:relo/providers/notification_provider.dart';
import 'package:relo/providers/message_provider.dart';
import 'package:relo/services/app_notification_service.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:relo/screen/friend_requests_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Import background handler từ app_notification_service
import 'package:relo/services/app_notification_service.dart'
    show firebaseMessagingBackgroundHandler;

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
  ServiceLocator.websocketService.setAuthErrorHandler(() async {
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
      ServiceLocator.websocketService.connect();
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
  notificationService.setOnNotificationTapped((
    String conversationId,
    Map<String, dynamic>? payloadData,
  ) async {
    // Đợi một chút để đảm bảo app đã sẵn sàng
    await Future.delayed(const Duration(milliseconds: 300));

    final navigator = ServiceLocator.navigatorKey.currentState;
    if (navigator == null) {
      // Retry sau 1 giây
      Future.delayed(const Duration(seconds: 1), () {
        final retryNavigator = ServiceLocator.navigatorKey.currentState;
        if (retryNavigator != null) {
          // Check if friend request notification
          if (conversationId == 'friend_requests') {
            _navigateToFriendRequestsScreen(retryNavigator);
          } else {
            _navigateToChatScreen(
              conversationId,
              retryNavigator,
              payloadData: payloadData,
            );
          }
        }
      });
      return;
    }

    // Check if friend request notification
    if (conversationId == 'friend_requests') {
      _navigateToFriendRequestsScreen(navigator);
    } else {
      _navigateToChatScreen(
        conversationId,
        navigator,
        payloadData: payloadData,
      );
    }
  });

  // Setup reply callback
  _setupNotificationCallbacksContinued(notificationService);
}

/// Helper function để navigate tới FriendRequestsScreen
void _navigateToFriendRequestsScreen(NavigatorState navigator) {
  navigator.push(
    MaterialPageRoute(builder: (context) => const FriendRequestsScreen()),
  );
}

/// Helper function để navigate tới ChatScreen
Future<void> _navigateToChatScreen(
  String conversationId,
  NavigatorState navigator, {
  Map<String, dynamic>? payloadData,
}) async {
  try {
    // Fetch conversation details để có đầy đủ thông tin
    final messageService = ServiceLocator.messageService;
    final secureStorage = const SecureStorageService();
    final currentUserId = await secureStorage.getUserId();

    if (currentUserId == null) {
      return;
    }

    // Nếu có payloadData từ notification, sử dụng thông tin đó
    String? title;
    String? avatarUrl;
    bool? isGroup;
    List<String>? memberIds;

    if (payloadData != null) {
      // PHÂN BIỆT CHAT NHÓM VÀ CHAT 1-1
      final isGroupValue = payloadData['is_group'];
      isGroup = isGroupValue == 'true' || 
                isGroupValue == true || 
                isGroupValue == 1 ||
                isGroupValue == '1';
      
      if (isGroup == true) {
        // CHAT NHÓM: title = tên nhóm (conversation_name), avatar = conversation_avatar
        // Nếu không có tên nhóm thì fallback về "Cuộc trò chuyện"
        final conversationNameRaw = payloadData['conversation_name'] as String?;
        title = (conversationNameRaw != null && conversationNameRaw.trim().isNotEmpty) 
            ? conversationNameRaw.trim() 
            : 'Cuộc trò chuyện';
        avatarUrl = payloadData['conversation_avatar'] as String?;
        
        // Lấy memberIds và memberCount từ payload
        final memberIdsStr = payloadData['member_ids'] as String?;
        if (memberIdsStr != null && memberIdsStr.isNotEmpty) {
          memberIds = memberIdsStr.split(',').where((id) => id.trim().isNotEmpty).toList();
        }
      } else {
        // CHAT 1-1: title = tên người gửi (sender_name), avatar = sender_avatar
        // Lưu ý: title ở đây là tên người gửi (người gửi tin nhắn cho mình), không phải tên người nhận
        title = payloadData['sender_name'] as String?;
        avatarUrl = payloadData['sender_avatar'] as String?;
      }
    }

    // Nếu thiếu thông tin, fetch từ API
    if (title == null || isGroup == null) {
      final conversation = await messageService.fetchConversationById(
        conversationId,
      );

      if (conversation == null) {
        // Fallback với thông tin tối thiểu
        navigator.push(
          MaterialPageRoute(
            builder: (context) =>
                ChatScreen(conversationId: conversationId, isGroup: false),
          ),
        );
        return;
      }

      // Extract thông tin từ conversation
      final participants = List<Map<String, dynamic>>.from(
        conversation['participants'] ?? [],
      );
      
      isGroup = conversation['isGroup'] ?? false;
      
      // Lấy memberIds cho chat nhóm
      if (isGroup == true) {
        memberIds = participants.map((p) => p['id'] as String).toList();
      }
      
      final otherParticipants = participants
          .where((p) => p['id'] != currentUserId)
          .toList();

      if (title == null) {
        if (isGroup!) {
          // CHAT NHÓM: title = tên nhóm (hoặc "Cuộc trò chuyện" nếu không có)
          final nameList = otherParticipants
              .map((p) => p['displayName'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .join(", ");
          final conversationName = conversation['name'] as String?;
          title = (conversationName != null && conversationName.trim().isNotEmpty)
              ? conversationName.trim()
              : (nameList.isNotEmpty ? nameList : 'Cuộc trò chuyện');
        } else {
          // CHAT 1-1: title = tên người gửi (không phải người nhận)
          // Nếu đang ở đây nghĩa là từ notification, nên cần lấy tên người gửi từ payloadData
          // Nếu không có payloadData thì lấy tên của người còn lại (người mà mình đang chat với)
          // Nhưng lưu ý: đây là tên để hiển thị trên chat screen, nên có thể là tên người nhận
          // Tuy nhiên, logic hiện tại đúng vì đây là tên để hiển thị trên ChatScreen
          final friend = otherParticipants.isNotEmpty
              ? otherParticipants.first
              : null;
          if (friend != null) {
            final isDeletedAccount =
                friend['username'] == 'deleted' || friend['id'] == 'deleted';

            if (isDeletedAccount) {
              title = 'Tài khoản không tồn tại';
              avatarUrl = null;
            } else {
              title = friend['displayName'] as String? ?? 'Người dùng';
            }
          } else {
            title = 'Người dùng';
          }
        }
      }

      if (avatarUrl == null) {
        if (isGroup!) {
          avatarUrl =
              conversation['avatarUrl'] as String? ??
              'assets/none_images/group.jpg';
        } else {
          final friend = otherParticipants.isNotEmpty
              ? otherParticipants.first
              : null;
          if (friend != null) {
            final isDeletedAccount =
                friend['username'] == 'deleted' || friend['id'] == 'deleted';
            if (!isDeletedAccount) {
              avatarUrl = ((friend['avatarUrl'] as String?) ?? '').isNotEmpty
                  ? friend['avatarUrl'] as String?
                  : 'assets/none_images/avatar.jpg';
            } else {
              avatarUrl = null;
            }
          } else {
            avatarUrl = 'assets/none_images/avatar.jpg';
          }
        }
      }
    }

    // Navigate với đầy đủ thông tin
    navigator.push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversationId,
          isGroup: isGroup ?? false,
          chatName: title ?? 'Người dùng',
          avatarUrl: avatarUrl,
          memberIds: memberIds,
          memberCount: memberIds?.length ?? 0,
          onConversationSeen: (String conversationId) {
            // Mark as seen
            messageService.markAsSeen(conversationId, currentUserId);
          },
          onLeftGroup: () {
            // Handler cho khi rời nhóm
          },
          onMuteToggled: () {
            // Handler cho khi toggle mute
          },
        ),
      ),
    );

    // Mark as seen
    await messageService.markAsSeen(conversationId, currentUserId);
  } catch (e) {
    // Fallback: navigate với thông tin tối thiểu
    navigator.push(
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(conversationId: conversationId, isGroup: false),
      ),
    );
  }
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
        return;
      }

      // Gửi tin nhắn reply qua API
      final messageService = ServiceLocator.messageService;
      await messageService.sendMessage(conversationId, {
        'type': 'text',
        'text': messageText,
      }, senderId);
    } catch (e) {
      // Silent fail
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

    // Set initial state - app đang ở foreground khi khởi động
    AppNotificationService().setAppLifecycleState(true);

    // Đảm bảo callback được setup sau khi app đã build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Kiểm tra lại initial message sau khi app đã sẵn sàng
      Future.delayed(const Duration(milliseconds: 1000), () async {
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          final conversationId =
              initialMessage.data['conversation_id'] as String?;
          if (conversationId != null && conversationId.isNotEmpty) {
            final navigator = ServiceLocator.navigatorKey.currentState;
            if (navigator != null) {
              _navigateToChatScreen(
                conversationId,
                navigator,
                payloadData: initialMessage.data,
              );
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Update notification service về app lifecycle state
    final notificationService = AppNotificationService();

    // Khi app trở lại foreground
    if (state == AppLifecycleState.resumed) {
      // Set app đang ở foreground - không hiển thị notification
      notificationService.setAppLifecycleState(true);

      // Delay một chút để đảm bảo app đã sẵn sàng
      Future.delayed(const Duration(milliseconds: 1000), () async {
        // Kiểm tra nếu user đã đăng nhập
        const storage = SecureStorageService();
        final refreshToken = await storage.getRefreshToken();
        if (refreshToken != null) {
          // Chỉ reconnect nếu thực sự disconnected
          // Tránh reconnect liên tục
          if (!ServiceLocator.websocketService.isConnected) {
            try {
              // Chỉ gọi connect một lần, không reconnect liên tục
              await ServiceLocator.websocketService.connect();
            } catch (e) {
              // Không làm gì, để tránh vòng lặp reconnect
            }
          }
        }
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Set app đang ở background/terminated - hiển thị notification
      notificationService.setAppLifecycleState(false);

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
