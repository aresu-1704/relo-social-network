import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:relo/firebase_options.dart';
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
  bool _isAppInForeground = true; // Track app lifecycle state

  // Callback để xử lý navigation và reply
  Function(String conversationId, Map<String, dynamic>? payloadData)?
  onNotificationTapped;
  Function(String conversationId, String messageText)? onNotificationReply;

  bool get hasReplyCallback => onNotificationReply != null;

  /// Update app lifecycle state
  void setAppLifecycleState(bool isInForeground) {
    _isAppInForeground = isInForeground;
  }

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
    } catch (e) {}
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
    } catch (e) {}
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
          onNotificationTapped!(conversationId, data);
        }
      } catch (e) {
        // Silent fail
      }
      return;
    }

    // Xử lý tap notification thông thường
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // Parse payload
        final data = _parsePayload(response.payload!);

        // Sử dụng _handleNotificationTap để xử lý tất cả các loại notification
        _handleNotificationTap(data);
      } catch (e) {
        // Silent fail
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
          final result = Map<String, dynamic>.from(decoded);
          return result;
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
    // Foreground messages - chỉ hiển thị khi app ở background
    // Nếu app đang foreground, không hiển thị notification (WebSocket đã handle)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Chỉ hiển thị notification nếu app đang ở background
      // Khi app foreground, WebSocket sẽ handle realtime messages
      if (!_isAppInForeground) {
        _showLocalNotification(message);
      }
    });

    // Background message tap (app đang ở background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Delay nhỏ để đảm bảo app đã resume
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(message.data);
      });
    });

    // Kiểm tra notification khi app được mở từ terminated state
    // Lưu lại để xử lý sau khi app đã khởi tạo xong
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        // Delay để đảm bảo app đã sẵn sàng (navigator đã được setup)
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleNotificationTap(message.data);
        });
      }
    });
  }

  /// Handle notification tap và navigate
  void _handleNotificationTap(Map<String, dynamic> data) {
    final notificationType = data['type'] as String?;
    final conversationId = data['conversation_id'] as String?;
    final screen = data['screen'] as String?;

    // Handle friend request notification
    if (notificationType == 'friend_request' || screen == 'friend_requests') {
      if (onNotificationTapped != null) {
        // Sử dụng 'friend_requests' làm identifier cho friend request screen
        onNotificationTapped!('friend_requests', data);
      }
      return;
    }

    // Handle chat message notification
    if (conversationId != null && conversationId.isNotEmpty) {
      // Gọi callback để navigate với payload data
      if (onNotificationTapped != null) {
        onNotificationTapped!(conversationId, data);
      }
    }
  }

  /// Set callback cho notification tap
  void setOnNotificationTapped(
    Function(String conversationId, Map<String, dynamic>? payloadData) callback,
  ) {
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

  /// Load ảnh nhóm mặc định từ assets và copy vào temp directory
  Future<String?> _loadDefaultGroupAvatarFromAssets() async {
    try {
      // Thử load ảnh từ assets/none_images/group.jpg
      ByteData data;
      try {
        data = await rootBundle.load('assets/none_images/group.jpg');
      } catch (e) {
        // Fallback: thử dùng avatar.jpg
        try {
          data = await rootBundle.load('assets/none_images/avatar.jpg');
        } catch (e2) {
          // Fallback cuối: icon.png
          try {
            data = await rootBundle.load('assets/icons/icon.png');
          } catch (e3) {
            return null;
          }
        }
      }

      final Uint8List bytes = data.buffer.asUint8List();

      // Copy vào temp directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/default_group_avatar.jpg';
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

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      if (data.isEmpty) return;

      final notification = message.notification;
      final notificationType = data['type'] as String?;
      final screen = data['screen'] as String?;

      // --- Friend request ---
      if (notificationType == 'friend_request' || screen == 'friend_requests') {
        final notif =
            notification ??
            RemoteNotification(
              title: data['title'] as String?,
              body: data['body'] as String?,
            );
        await _showFriendRequestNotification(notif, data);
        return;
      }

      // --- Basic fields ---
      // PHÂN BIỆT CHAT NHÓM VÀ CHAT 1-1 dựa trên flag is_group
      // Backend gửi: "true" (string) hoặc true (bool) = chat nhóm
      //              "false" (string) hoặc false (bool) = chat 1-1
      final isGroupValue = data['is_group'];
      final isGroup = isGroupValue == 'true' || 
                     isGroupValue == true || 
                     isGroupValue == 1 ||
                     isGroupValue == '1';
      
      final conversationId = data['conversation_id'] as String? ?? '';
      
      // Đảm bảo senderName luôn có giá trị
      final senderNameRaw = data['sender_name'] as String? ?? '';
      final senderName = senderNameRaw.trim().isEmpty ? 'Người dùng' : senderNameRaw.trim();
      
      // Đảm bảo conversationName luôn có giá trị cho group
      final conversationNameRaw = data['conversation_name'] as String? ?? '';
      final conversationName = conversationNameRaw.trim().isEmpty 
          ? (isGroup ? 'Cuộc trò chuyện' : '') 
          : conversationNameRaw.trim();
      final contentType = data['content_type'] as String? ?? 'text';
      final hasReply = data['has_reply'] == 'true' || data['has_reply'] == true;

      // --- Avatar: PHÂN BIỆT RÕ RÀNG ---
      // CHAT NHÓM: dùng conversation_avatar (ảnh nhóm)
      // CHAT 1-1: dùng sender_avatar (ảnh người gửi)
      String? avatarPath;
      String? avatarUrl;
      if (isGroup) {
        // Chat nhóm: lấy avatar nhóm
        avatarUrl = data['conversation_avatar'] as String?;
      } else {
        // Chat 1-1: lấy avatar người gửi
        avatarUrl = data['sender_avatar'] as String?;
      }

      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        avatarPath = await _downloadImageForNotification(avatarUrl);
        if (avatarPath != null && avatarPath.isEmpty) avatarPath = null;
      }
      // Đảm bảo LUÔN có avatar (fallback về default nếu không có)
      if (avatarPath == null) {
        avatarPath = isGroup
            ? await _loadDefaultGroupAvatarFromAssets()
            : await _loadDefaultAvatarFromAssets();
        // Nếu vẫn null, thử lại một lần nữa
        if (avatarPath == null) {
          try {
            if (isGroup) {
              // Fallback cuối cho group: dùng avatar.jpg
              final assetData = await rootBundle.load('assets/none_images/avatar.jpg');
              final bytes = assetData.buffer.asUint8List();
              final tempDir = await getTemporaryDirectory();
              final filePath = '${tempDir.path}/default_group_avatar_final.jpg';
              final file = File(filePath);
              await file.writeAsBytes(bytes);
              if (await file.exists()) {
                avatarPath = filePath;
              }
            } else {
              // Fallback cuối cho 1-1: dùng icon.png
              final assetData = await rootBundle.load('assets/icons/icon.png');
              final bytes = assetData.buffer.asUint8List();
              final tempDir = await getTemporaryDirectory();
              final filePath = '${tempDir.path}/default_avatar_final.png';
              final file = File(filePath);
              await file.writeAsBytes(bytes);
              if (await file.exists()) {
                avatarPath = filePath;
              }
            }
          } catch (e) {
            // Final fallback - không có avatar
          }
        }
      }

      // --- Nội dung hiển thị ---
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
          formattedContent = notification?.body ?? 'Đã gửi tin nhắn';
      }

      // Nếu là nhóm: thêm tên người gửi
      if (isGroup && senderName.isNotEmpty) {
        final prefix = '${senderName.trim()}:';
        if (!formattedContent.toLowerCase().startsWith(prefix.toLowerCase())) {
          formattedContent = '$senderName: $formattedContent';
        }
      }

      // --- Title/Body: PHÂN BIỆT RÕ RÀNG ---
      // CHAT NHÓM: Title = tên nhóm (hoặc "Cuộc trò chuyện" nếu không có tên), Body = "Tên người gửi: Nội dung"
      // CHAT 1-1: Title = tên người gửi, Body = nội dung
      // Đảm bảo chat nhóm LUÔN có title hợp lệ, không được dùng tên người gửi
      final title = isGroup
          ? (conversationName.isNotEmpty ? conversationName : 'Cuộc trò chuyện')
          : (senderName.isNotEmpty ? senderName : 'Người dùng');
      final body = formattedContent;

      // --- Payload JSON ---
      String payload = jsonEncode(data);

      // --- Android details ---
      final person = Person(
        name: senderName,
        icon: avatarPath != null ? BitmapFilePathAndroidIcon(avatarPath) : null,
      );
      final style = MessagingStyleInformation(
        person,
        messages: [Message(formattedContent, DateTime.now(), person)],
      );

      final androidDetails = AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Relo chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        category: AndroidNotificationCategory.message,
        groupKey: conversationId.isNotEmpty ? 'conv_$conversationId' : null,
        styleInformation: style,
        largeIcon: avatarPath != null
            ? FilePathAndroidBitmap(avatarPath)
            : null,
        actions: hasReply
            ? [
                AndroidNotificationAction(
                  'REPLY',
                  'Trả lời',
                  showsUserInterface: true,
                  titleColor: const Color(0xFF7A2FC0),
                  cancelNotification: false,
                ),
              ]
            : null,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      final id = conversationId.isNotEmpty
          ? conversationId.hashCode
          : DateTime.now().hashCode;

      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      // optional: print debug log
    }
  }

  /// Show friend request notification
  Future<void> _showFriendRequestNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) async {
    try {
      final fromUserName =
          data['title'] as String? ?? data['sender_name'] as String?;
      final fromUserAvatar =
          data['sender_avatar'] as String? ??
          data['from_user_avatar'] as String?;

      // Download avatar để hiển thị
      String? avatarPath;
      if (fromUserAvatar != null && fromUserAvatar.isNotEmpty) {
        avatarPath = await _downloadImageForNotification(fromUserAvatar);
        if (avatarPath != null && avatarPath.isEmpty) {
          avatarPath = null;
        }
      }

      // Nếu không có avatar, sử dụng ảnh mặc định
      if (avatarPath == null || avatarPath.isEmpty) {
        avatarPath = await _loadDefaultAvatarFromAssets();
      }

      // Parse payload
      String payload;
      try {
        payload = jsonEncode(data);
      } catch (e) {
        payload = data.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      }

      // Tạo notification details
      final androidDetails = AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Notifications from Relo social network',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        largeIcon: avatarPath != null
            ? FilePathAndroidBitmap(avatarPath)
            : null,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Hiển thị notification
      await _localNotifications.show(
        'friend_request_${data['from_user_id'] ?? DateTime.now().millisecondsSinceEpoch}'
            .hashCode,
        notification.title ?? 'Lời mời kết bạn',
        notification.body ?? '$fromUserName muốn kết bạn với bạn',
        details,
        payload: payload,
      );
    } catch (e) {
      // Silent fail
    }
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
    String? senderAvatarUrl,
    String? senderName,
    String? conversationId,
    bool hasReply = false,
  }) async {
    // Download avatar để hiển thị
    String? avatarPath;
    if (senderAvatarUrl != null && senderAvatarUrl.isNotEmpty) {
      avatarPath = await _downloadImageForNotification(senderAvatarUrl);
      if (avatarPath != null && avatarPath.isEmpty) {
        avatarPath = null;
      }
    }

    // Nếu không có avatar từ URL, sử dụng ảnh mặc định từ assets
    if (avatarPath == null) {
      avatarPath = await _loadDefaultAvatarFromAssets();
    }

    // Sử dụng MessagingStyle để hiển thị avatar bên trái (giống MessagesScreen)
    // Tag để group notifications (chỉ 1 notification per conversation)
    AndroidNotificationDetails androidDetails;
    if (hasReply && conversationId != null) {
      // Notification với reply action
      androidDetails = AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Notifications from Relo social network',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        category: AndroidNotificationCategory.message,
        tag: conversationId, // Group notifications theo conversation_id
        styleInformation: MessagingStyleInformation(
          Person(
            name: senderName ?? title,
            icon: avatarPath != null
                ? BitmapFilePathAndroidIcon(avatarPath)
                : null,
          ),
          messages: [
            Message(
              body,
              DateTime.now(),
              Person(
                name: senderName ?? title,
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
            showsUserInterface: true,
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
            name: senderName ?? title,
            icon: avatarPath != null
                ? BitmapFilePathAndroidIcon(avatarPath)
                : null,
          ),
          messages: [
            Message(
              body,
              DateTime.now(),
              Person(
                name: senderName ?? title,
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

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Sử dụng conversation_id để group notifications (nếu có)
    final notificationId = conversationId != null && conversationId.isNotEmpty
        ? conversationId.hashCode
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notificationId,
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Khởi tạo local notifications plugin
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  // Tạo Android notification channel
  const androidChannel = AndroidNotificationChannel(
    'relo_channel',
    'Relo Notifications',
    description: 'Notifications from Relo social network',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  await localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(androidChannel);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await localNotifications.initialize(settings);

  // Hiển thị notification từ data (data-only message)
  final data = message.data;
  final notificationType = data['type'] as String?;
  final screen = data['screen'] as String?;

  // Handle friend request notification (data-only)
  if (notificationType == 'friend_request' || screen == 'friend_requests') {
    final fromUserName =
        data['from_user_name'] as String? ?? data['sender_name'] as String?;

    // Parse payload
    String payload;
    try {
      payload = jsonEncode(data);
    } catch (e) {
      payload = data.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }

    // Tạo notification details cho friend request
    final androidDetails = AndroidNotificationDetails(
      'relo_channel',
      'Relo Notifications',
      channelDescription: 'Notifications from Relo social network',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Hiển thị notification từ data
    await localNotifications.show(
      'friend_request_${data['from_user_id'] ?? DateTime.now().millisecondsSinceEpoch}'
          .hashCode,
      data['title'] as String? ?? 'Lời mời kết bạn',
      data['body'] as String? ?? '$fromUserName muốn kết bạn với bạn',
      details,
      payload: payload,
    );
    return;
  }

  // Handle chat message notification
  // Backend gửi data-only messages, cần xử lý từ data
  final notification = message.notification;
  
  final conversationId = data['conversation_id'] as String?;
  final hasReply = data['has_reply'] == 'true';
  
  // PHÂN BIỆT CHAT NHÓM VÀ CHAT 1-1 dựa trên flag is_group
  // Backend gửi: "true" (string) hoặc true (bool) = chat nhóm
  //              "false" (string) hoặc false (bool) = chat 1-1
  final isGroupValue = data['is_group'];
  final isGroup = isGroupValue == 'true' || 
                 isGroupValue == true || 
                 isGroupValue == 1 ||
                 isGroupValue == '1';
  
  // Đảm bảo senderName luôn có giá trị
  final senderNameRaw = (data['sender_name'] as String? ?? '').trim();
  final senderName = senderNameRaw.isEmpty 
      ? ((notification?.title ?? '').trim().isEmpty ? 'Người dùng' : notification!.title!)
      : senderNameRaw;
  
  final contentType = data['content_type'] as String? ?? 'text';
  final messageContent = (data['body'] as String? ?? '').trim().isEmpty
      ? (notification?.body ?? '')
      : (data['body'] as String? ?? '');
  
  // --- Avatar: PHÂN BIỆT RÕ RÀNG ---
  // CHAT NHÓM: lấy conversation_avatar (ảnh nhóm)
  // CHAT 1-1: lấy sender_avatar (ảnh người gửi)
  String? avatarUrl;
  if (isGroup) {
    // Chat nhóm: dùng avatar nhóm
    avatarUrl = data['conversation_avatar'] as String?;
  } else {
    // Chat 1-1: dùng avatar người gửi
    avatarUrl = data['sender_avatar'] as String?;
  }
  
  // Download avatar nếu có
  String? avatarPath;
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse(avatarUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final hash = avatarUrl.hashCode.abs().toString();
        final extension = avatarUrl.toLowerCase().contains('.png')
            ? '.png'
            : (avatarUrl.toLowerCase().contains('.jpg') || avatarUrl.toLowerCase().contains('.jpeg'))
                ? '.jpg'
                : '.png';
        final filePath = '${tempDir.path}/notification_$hash$extension';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (await file.exists()) {
          avatarPath = filePath;
        }
      }
    } catch (e) {
      // Silent fail, sẽ dùng default avatar
    }
  }
  
  // Đảm bảo LUÔN có avatar (fallback về default nếu không có)
  if (avatarPath == null) {
    if (isGroup) {
      // Load default group avatar từ assets
      try {
        final assetData = await rootBundle.load('assets/none_images/group.jpg');
        final bytes = assetData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/default_group_avatar.jpg';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        if (await file.exists()) {
          avatarPath = filePath;
        }
      } catch (e) {
        // Fallback tiếp: dùng avatar.jpg
        try {
          final assetData = await rootBundle.load('assets/none_images/avatar.jpg');
          final bytes = assetData.buffer.asUint8List();
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/default_group_avatar_fallback.jpg';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          if (await file.exists()) {
            avatarPath = filePath;
          }
        } catch (e2) {
          // Fallback cuối: dùng icon.png
          try {
            final assetData = await rootBundle.load('assets/icons/icon.png');
            final bytes = assetData.buffer.asUint8List();
            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/default_group_avatar_final.png';
            final file = File(filePath);
            await file.writeAsBytes(bytes);
            if (await file.exists()) {
              avatarPath = filePath;
            }
          } catch (e3) {
            // Final fallback - không có avatar
          }
        }
      }
    } else {
      // Load default avatar từ assets cho chat 1-1
      try {
        final assetData = await rootBundle.load('assets/none_images/avatar.jpg');
        final bytes = assetData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/default_avatar.jpg';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        if (await file.exists()) {
          avatarPath = filePath;
        }
      } catch (e) {
        // Fallback: dùng icon.png
        try {
          final assetData = await rootBundle.load('assets/icons/icon.png');
          final bytes = assetData.buffer.asUint8List();
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/default_avatar_fallback.png';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          if (await file.exists()) {
            avatarPath = filePath;
          }
        } catch (e2) {
          // Final fallback - không có avatar
        }
      }
    }
  }

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

  // Nếu là group chat và nội dung chưa có format "Tên người gửi: " thì thêm vào
  if (isGroup && senderName.isNotEmpty) {
    // Kiểm tra xem formattedContent đã có format "Tên: " chưa
    final senderNamePrefix = '$senderName: ';
    if (!formattedContent.startsWith(senderNamePrefix)) {
      formattedContent = '$senderNamePrefix$formattedContent';
    }
  }

  // --- Title/Body: PHÂN BIỆT RÕ RÀNG ---
  // CHAT NHÓM: title = tên nhóm (fallback "Cuộc trò chuyện"), body = "Tên người gửi: Nội dung"
  // CHAT 1-1: title = tên người gửi, body = nội dung
  // Đảm bảo chat nhóm LUÔN có title hợp lệ, không được dùng tên người gửi
  final conversationNameRaw = (data['conversation_name'] as String? ?? '').trim();
  final conversationName = conversationNameRaw.isEmpty 
      ? (isGroup ? 'Cuộc trò chuyện' : '') 
      : conversationNameRaw;
  final notificationTitle = isGroup
      ? (conversationName.isNotEmpty ? conversationName : 'Cuộc trò chuyện')
      : (senderName.isNotEmpty ? senderName : 'Người dùng');
  final notificationBody = formattedContent;

  // Parse payload thành JSON string
  String payload;
  try {
    payload = jsonEncode(data);
  } catch (e) {
    // Fallback nếu không encode được
    try {
      payload = data.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
      payload = '{$payload}';
    } catch (e2) {
      payload = data.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
  }

  // Tạo notification details với tag để group notifications
  // Tạo Person với avatar
  final person = Person(
    name: senderName,
    icon: avatarPath != null ? BitmapFilePathAndroidIcon(avatarPath) : null,
  );
  
  AndroidNotificationDetails androidDetails;
  if (hasReply && conversationId != null) {
    androidDetails = AndroidNotificationDetails(
      'relo_channel',
      'Relo Notifications',
      channelDescription: 'Notifications from Relo social network',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.message,
      tag: conversationId, // Group notifications theo conversation_id
      styleInformation: MessagingStyleInformation(
        person,
        messages: [
          Message(formattedContent, DateTime.now(), person),
        ],
      ),
      largeIcon: avatarPath != null
          ? FilePathAndroidBitmap(avatarPath)
          : null,
      actions: [
        AndroidNotificationAction(
          'REPLY',
          'Trả lời',
          showsUserInterface: true,
          titleColor: const Color(0xFF7A2FC0),
          cancelNotification: false,
        ),
      ],
    );
  } else {
    androidDetails = AndroidNotificationDetails(
      'relo_channel',
      'Relo Notifications',
      channelDescription: 'Notifications from Relo social network',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      tag: conversationId, // Group notifications theo conversation_id
      styleInformation: MessagingStyleInformation(
        person,
        messages: [
          Message(formattedContent, DateTime.now(), person),
        ],
      ),
      largeIcon: avatarPath != null
          ? FilePathAndroidBitmap(avatarPath)
          : null,
    );
  }

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  final notificationId = conversationId != null && conversationId.isNotEmpty
      ? conversationId.hashCode
      : message.hashCode;

  await localNotifications.show(
    notificationId,
    notificationTitle,
    notificationBody,
    details,
    payload: payload,
  );
}
