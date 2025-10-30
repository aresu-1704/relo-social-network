import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:relo/screen/login_screen.dart';
import 'package:relo/services/app_connectivity_service.dart';
import 'package:relo/services/connectivity_service.dart';
import 'package:relo/services/dio_api_service.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/services/post_service.dart';
import 'package:relo/services/notification_service.dart';
import 'package:relo/services/comment_service.dart';
import 'package:relo/services/websocket_service.dart';

class ServiceLocator {
  // Global navigator key to allow navigation from outside the widget tree
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Service instances
  static late final DioApiService dioApiService;
  static late final Dio dio;
  static late final AuthService authService;
  static late final UserService userService;
  static late final MessageService messageService;
  static late final PostService postService;
  static late final NotificationService notificationService;
  static late final CommentService commentService;
  static late final ConnectivityService connectivityService;
  static late final AppConnectivityService appConnectivityService;
  static late final WebSocketService websocketService;

  /// Initializes all the services.
  static void init() {
    // This function will be called from the DioApiService when the refresh token fails.
    void onSessionExpired() {
      // Use the navigator key to navigate to the login screen, clearing all other routes.
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }

    // This function will be called when account is deleted
    void onAccountDeleted(String message) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                SizedBox(width: 10),
                Text('Tài khoản đã bị xóa'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                const Text(
                  'Tài khoản của bạn đã bị xóa và không thể tiếp tục sử dụng.\n\n'
                  'Vui lòng liên hệ bộ phận hỗ trợ nếu bạn cho rằng đây là lỗi.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Navigate to login screen
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    }

    // Initialize the app connectivity service
    appConnectivityService = AppConnectivityService();

    // Create the core DioApiService with the session expiration callback
    dioApiService = DioApiService(
      onSessionExpired: onSessionExpired,
      appConnectivityService: appConnectivityService,
      onAccountDeleted: onAccountDeleted,
    );
    dio = dioApiService.dio;

    // Create other services that depend on the central Dio instance
    // Note: AuthService uses its own Dio instance for non-intercepted calls like login/register
    authService = AuthService();
    userService = UserService(dio);
    messageService = MessageService(dio);
    postService = PostService(dio);
    notificationService = NotificationService(dio);
    commentService = CommentService(dio);
    // Use global singleton instance for WebSocket to keep single connection
    websocketService = webSocketService;

    // Initialize the connectivity service
    connectivityService = ConnectivityService();
  }
}
