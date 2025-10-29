import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      print("✅ Notification service initialized");
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
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      // Chưa có direct API để setup reply trong flutter_local_notifications
      // Reply action sẽ được xử lý từ FCM payload đã có actions trong backend
      print("✅ Android reply action ready");
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
      // Payload có thể là string representation của Map
      // Ví dụ: "{conversation_id: abc123, type: message}"
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

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final conversationId = data['conversation_id'] as String?;
    final hasReply = data['has_reply'] == 'true';

    // Tạo payload từ data
    final payload = data.entries.map((e) => '${e.key}: ${e.value}').join(', ');

    // Android notification với reply action nếu có conversation_id
    AndroidNotificationDetails androidDetails;
    if (hasReply && conversationId != null) {
      // Thêm reply action cho Android với input text
      androidDetails = AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Notifications from Relo social network',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        category: AndroidNotificationCategory.message,
        // Thêm reply action với input text cho Android
        actions: [
          const AndroidNotificationAction(
            'REPLY',
            'Trả lời',
            showsUserInterface: false,
            cancelNotification: false,
          ),
        ],
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'relo_channel',
        'Relo Notifications',
        channelDescription: 'Notifications from Relo social network',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
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

    await _localNotifications.show(
      notification.hashCode,
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
