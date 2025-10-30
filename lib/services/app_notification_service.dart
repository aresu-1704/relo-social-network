import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Debug: Kiểm tra callback đã được setup chưa
  bool get hasReplyCallback => onNotificationReply != null;

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
      onDidReceiveNotificationResponse: _onNotificationResponse,
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
      }
    } catch (e) {
    }
  }

  /// Handle notification tap và reply action
  static void _onNotificationResponse(NotificationResponse response) {
    // Get instance để truy cập callback
    final instance = AppNotificationService._instance;
    instance._handleNotificationResponseImpl(response);
  }

  /// Implementation của notification response handler
  void _handleNotificationResponseImpl(NotificationResponse response) {
    // Xử lý reply action - mở chat screen như tap notification thông thường
    final actionId = response.actionId?.toUpperCase().trim() ?? '';
    final isReplyAction = actionId == 'REPLY' || actionId.contains('REPLY');

    // Nếu là reply action, xử lý như tap notification để mở chat screen
    if (isReplyAction &&
        response.payload != null &&
        response.payload!.isNotEmpty) {
      try {
        final data = _parsePayload(response.payload!);
        final conversationId = data['conversation_id'] as String?;

        if (conversationId != null && onNotificationTapped != null) {
          onNotificationTapped!(conversationId);
        }
      } catch (e) {
        // Silent fail
      }
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
      }
    }
  }

  /// Parse payload string thành Map
  Map<String, dynamic> _parsePayload(String payload) {
    try {
      // Thử parse như JSON đúng cách trước
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        // Not valid JSON, try manual parse
      }

      // Thử parse như JSON-like string (với quotes)
      if (payload.trim().startsWith('{')) {
        // Remove outer braces và parse
        final cleaned = payload
            .replaceAll('{', '')
            .replaceAll('}', '')
            .replaceAll(' ', '');

        final Map<String, dynamic> result = {};
        final pairs = cleaned.split(',');

        for (final pair in pairs) {
          if (pair.contains(':')) {
            final parts = pair.split(':');
            if (parts.length >= 2) {
              var key = parts[0].trim().replaceAll('"', '').replaceAll("'", '');
              var value = parts.sublist(1).join(':').trim();
              // Remove quotes nếu có
              if (value.startsWith('"') && value.endsWith('"')) {
                value = value.substring(1, value.length - 1);
              } else if (value.startsWith("'") && value.endsWith("'")) {
                value = value.substring(1, value.length - 1);
              }
              result[key] = value;
            }
          }
        }
        return result;
      }

      // Fallback: parse format đơn giản "key: value, key2: value2"
      final cleaned = payload.replaceAll(' ', '');
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
    } catch (e) {
      return {};
    }
  }

  /// Setup Firebase message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
      _handleNotificationTap(message.data);
    });

    // Kiểm tra notification khi app được mở từ terminated state
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
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

  /// Load ảnh mặc định từ assets và copy vào temp directory
  Future<String?> _loadDefaultAvatarFromAssets() async {
    try {
      // Thử load ảnh từ assets/none_images/avatar.jpg trước
      ByteData data;
      try {
        data = await rootBundle.load('assets/none_images/avatar.jpg');
      } catch (e) {
        // Fallback: thử dùng icon.png
        try {
          data = await rootBundle.load('assets/icons/icon.png');
        } catch (e2) {
          return null;
        }
      }

      final Uint8List bytes = data.buffer.asUint8List();

      // Copy vào temp directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/default_avatar.jpg';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Validate file was created successfully
      if (await file.exists()) {
        return filePath;
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }

  /// Download image từ URL về local để hiển thị trong notification
  Future<String?> _downloadImageForNotification(String imageUrl) async {
    try {
      // Validate imageUrl
      if (imageUrl.isEmpty) {
        return null;
      }

      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme) {
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
      // Silent fail
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
      if (avatarPath != null && avatarPath.isEmpty) {
        avatarPath = null;
      }
    }

    // Nếu không có avatar từ URL, sử dụng ảnh mặc định từ assets
    if (avatarPath == null) {
      avatarPath = await _loadDefaultAvatarFromAssets();
    }

    // Format message content giống MessagesScreen
    final contentType = data['content_type'] as String? ?? 'text';
    final messageContent = notification.body ?? '';
    String formattedContent;

    switch (contentType) {
      case 'audio':
        formattedContent = '🎤 [Tin nhắn thoại]';
        break;
      case 'media':
        formattedContent = '🖼️ [Đa phương tiện]';
        break;
      case 'file':
        formattedContent = '📁 [Tệp tin]';
        break;
      case 'delete':
        formattedContent = '[Tin nhắn đã bị thu hồi]';
        break;
      default:
        formattedContent = messageContent.isNotEmpty
            ? messageContent
            : 'Đã gửi tin nhắn';
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

    // Sử dụng MessagingStyle để hiển thị avatar bên trái (Android 7.0+)
    AndroidNotificationDetails androidDetails;
    if (hasReply && conversationId != null) {
      // Notification với reply action và inline reply
      androidDetails = AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Notifications from Relo social network',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        category: AndroidNotificationCategory.message,
        styleInformation: MessagingStyleInformation(
          Person(
            name: senderName,
            icon: avatarPath != null
                ? BitmapFilePathAndroidIcon(avatarPath)
                : null,
          ),
          messages: [
            Message(
              formattedContent,
              DateTime.now(),
              Person(
                name: senderName,
                icon: avatarPath != null
                    ? BitmapFilePathAndroidIcon(avatarPath)
                    : null,
              ),
            ),
          ],
        ),
        largeIcon: avatarPath != null
            ? FilePathAndroidBitmap(avatarPath)
            : null,
        actions: [
          AndroidNotificationAction(
            'REPLY',
            'Trả lời',
            showsUserInterface: true, // Mở app khi bấm reply
            titleColor: const Color(0xFF7A2FC0),
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
        styleInformation: MessagingStyleInformation(
          Person(
            name: senderName,
            icon: avatarPath != null
                ? BitmapFilePathAndroidIcon(avatarPath)
                : null,
          ),
          messages: [
            Message(
              formattedContent,
              DateTime.now(),
              Person(
                name: senderName,
                icon: avatarPath != null
                    ? BitmapFilePathAndroidIcon(avatarPath)
                    : null,
              ),
            ),
          ],
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
      return token;
    } catch (e) {
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
}
