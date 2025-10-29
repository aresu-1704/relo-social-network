import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppNotificationService {
  static final AppNotificationService _instance =
      AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Callback để xử lý navigation và reply
  Function(String conversationId)? onNotificationTapped;
  Function(String conversationId, String messageText)? onNotificationReply;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission
      await requestPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup Firebase message handlers
      _setupMessageHandlers();

      _isInitialized = true;
    } catch (e) {
      print("❌ Error initializing notifications: $e");
    }
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print("Error requesting permission: $e");
      return false;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // Tạo notification channel với reply action cho Android
    const androidChannel = AndroidNotificationChannel(
      'relo_channel',
      'Relo Notifications',
      description: 'Notifications from Relo social network',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Đăng ký notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Setup reply action cho Android
    await _setupReplyAction();
  }

  /// Setup reply action cho Android
  Future<void> _setupReplyAction() async {
    try {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // Chưa có direct API để setup reply trong flutter_local_notifications
        // Reply action sẽ được xử lý từ FCM payload đã có actions trong backend
        print("✅ Android reply action ready");
      }
    } catch (e) {
      print("Error setting up reply action: $e");
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print("Notification tapped: ${response.payload}");
    print("Action ID: ${response.actionId}, Input: ${response.input}");

    // Xử lý reply action
    if (response.actionId == 'REPLY' && response.payload != null) {
      // Lấy text từ input field của notification
      final replyText = response.input ?? '';
      _handleReply(response.payload!, inputText: replyText);
      return;
    }

    // Xử lý tap notification thông thường
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // Parse payload để lấy conversation_id
        final data = _parsePayload(response.payload!);
        final conversationId = data['conversation_id'] as String?;

        if (conversationId != null && onNotificationTapped != null) {
          onNotificationTapped!(conversationId);
        }
      } catch (e) {
        print("Error parsing notification payload: $e");
      }
    }
  }

  /// Parse payload string thành Map
  Map<String, dynamic> _parsePayload(String payload) {
    try {
      // Thử parse như JSON trước
      if (payload.trim().startsWith('{')) {
        // Remove quotes và parse như JSON-like
        final cleaned = payload
            .replaceAll('{', '')
            .replaceAll('}', '')
            .replaceAll('"', '')
            .replaceAll(' ', '');

        final Map<String, dynamic> result = {};
        final pairs = cleaned.split(',');

        for (final pair in pairs) {
          if (pair.contains(':')) {
            final keyValue = pair.split(':');
            if (keyValue.length == 2) {
              final key = keyValue[0].trim();
              final value = keyValue[1].trim();
              result[key] = value;
            }
          }
        }
        return result;
      }

      // Fallback: parse format cũ "key: value, key2: value2"
      final cleaned = payload
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll(' ', '');

      final Map<String, dynamic> result = {};
      final pairs = cleaned.split(',');

      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          result[key] = value;
        }
      }

      return result;
    } catch (e) {
      print("Error parsing payload: $e");
      return {};
    }
  }

  /// Handle reply action
  void _handleReply(String payload, {String? inputText}) {
    try {
      final data = _parsePayload(payload);
      final conversationId = data['conversation_id'] as String?;

      if (conversationId != null && onNotificationReply != null) {
        // Reply text sẽ được lấy từ notification action input
        final replyText = inputText ?? '';
        if (replyText.isNotEmpty) {
          onNotificationReply!(conversationId, replyText);
          print(
            "✅ Reply action triggered for conversation: $conversationId with text: $replyText",
          );
        } else {
          print("⚠️ Reply action triggered but no input text provided");
        }
      }
    } catch (e) {
      print("Error handling reply: $e");
    }
  }

  /// Setup Firebase message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground message: ${message.notification?.title}");
      print("📩 Message data: ${message.data}");
      _showLocalNotification(message);

      // Xử lý reply nếu có
      if (message.data.containsKey('type') &&
          message.data['type'] == 'message' &&
          message.data.containsKey('conversation_id')) {
        // Notification đã được hiển thị với reply action từ backend
      }
    });

    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📩 Opened from background: ${message.notification?.title}");
      print("📩 Message data: ${message.data}");
      _handleNotificationTap(message.data);
    });

    // Kiểm tra notification khi app được mở từ terminated state
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print("📩 App opened from terminated state");
        _handleNotificationTap(message.data);
      }
    });
  }

  /// Handle notification tap và navigate
  void _handleNotificationTap(Map<String, dynamic> data) {
    final conversationId = data['conversation_id'] as String?;

    if (conversationId != null && conversationId.isNotEmpty) {
      // Gọi callback để navigate
      if (onNotificationTapped != null) {
        onNotificationTapped!(conversationId);
      }
    }
  }

  /// Set callback cho notification tap
  void setOnNotificationTapped(Function(String conversationId) callback) {
    onNotificationTapped = callback;
  }

  /// Set callback cho notification reply
  void setOnNotificationReply(
    Function(String conversationId, String messageText) callback,
  ) {
    onNotificationReply = callback;
  }

  /// Handle reply từ notification (được gọi từ platform-specific code)
  void handleReplyFromNotification(String conversationId, String replyText) {
    if (onNotificationReply != null) {
      onNotificationReply!(conversationId, replyText);
    }
  }

  /// Download image từ URL về local để hiển thị trong notification
  Future<String?> _downloadImageForNotification(String imageUrl) async {
    try {
      // Validate imageUrl
      if (imageUrl.isEmpty) {
        print('⚠️ Invalid image URL: empty string');
        return null;
      }

      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme) {
        print('⚠️ Invalid image URL: $imageUrl');
        return null;
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = imageUrl.split('/').last.split('?').first;

        // Validate fileName
        if (fileName.isEmpty) {
          // Fallback to hash-based filename
          final hash = imageUrl.hashCode.abs().toString();
          final extension = imageUrl.toLowerCase().contains('.png')
              ? '.png'
              : imageUrl.toLowerCase().contains('.jpg') ||
                    imageUrl.toLowerCase().contains('.jpeg')
              ? '.jpg'
              : '.png';
          final filePath = '${tempDir.path}/notification_$hash$extension';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          // Validate file was created successfully
          if (await file.exists()) {
            return filePath;
          }
        } else {
          final filePath = '${tempDir.path}/notification_$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          // Validate file was created successfully
          if (await file.exists()) {
            return filePath;
          }
        }
      }
    } catch (e) {
      print("⚠️ Error downloading image for notification: $e");
    }
    return null;
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final conversationId = data['conversation_id'] as String?;
    final hasReply = data['has_reply'] == 'true';
    final senderAvatar = data['sender_avatar'] as String?;
    // final imageUrl = data['image_url'] as String?; // Reserved for future use
    final senderName =
        data['sender_name'] as String? ?? notification.title ?? '';

    // Download avatar để hiển thị largeIcon
    String? avatarPath;
    if (senderAvatar != null && senderAvatar.isNotEmpty) {
      avatarPath = await _downloadImageForNotification(senderAvatar);
      // Validate avatarPath trước khi sử dụng
      if (avatarPath != null && avatarPath.isEmpty) {
        print('⚠️ Invalid avatar path: empty string');
        avatarPath = null;
      }
    }

    // Parse payload đúng cách (JSON string thay vì format key:value)
    String payload;
    try {
      // Thử parse như JSON trước
      payload = data.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
      payload = '{$payload}';
    } catch (e) {
      // Fallback về format cũ
      payload = data.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }

    // Sử dụng BigTextStyle để hiển thị đẹp hơn kiểu Zalo
    AndroidNotificationDetails androidDetails;
    if (hasReply && conversationId != null) {
      // Notification với reply action và BigTextStyle
      androidDetails = AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Notifications from Relo social network',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        category: AndroidNotificationCategory.message,
        styleInformation: BigTextStyleInformation(
          notification.body ?? '',
          contentTitle: notification.title ?? senderName,
          htmlFormatBigText: false,
        ),
        largeIcon: avatarPath != null
            ? FilePathAndroidBitmap(avatarPath)
            : null,
        actions: [
          const AndroidNotificationAction(
            'REPLY',
            'Trả lời',
            showsUserInterface: true, // Hiển thị input field khi reply
            titleColor: Color(0xFF7A2FC0),
            cancelNotification: false,
          ),
        ],
      );
    } else {
      // Notification không có reply action
      androidDetails = AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Notifications from Relo social network',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        styleInformation: BigTextStyleInformation(
          notification.body ?? '',
          contentTitle: notification.title ?? senderName,
          htmlFormatBigText: false,
        ),
        largeIcon: avatarPath != null
            ? FilePathAndroidBitmap(avatarPath)
            : null,
      );
    }

    // iOS notification với reply category
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: hasReply && conversationId != null
          ? 'REPLY_CATEGORY'
          : 'DEFAULT_CATEGORY',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Sử dụng conversation_id để group notifications (nếu có)
    // Điều này giúp Android tự động group notifications từ cùng một conversation
    final notificationId = conversationId != null && conversationId.isNotEmpty
        ? conversationId.hashCode
        : notification.hashCode;

    await _localNotifications.show(
      notificationId,
      notification.title,
      notification.body,
      details,
      payload: payload,
    );
  }

  /// Get device FCM token
  Future<String?> getDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      print("🔑 FCM Token: $token");
      return token;
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      return null;
    }
  }

  /// Show local notification manually
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'relo_channel',
      'Relo Notifications',
      channelDescription: 'Notifications from Relo social network',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("📩 Background message: ${message.notification?.title}");
}
