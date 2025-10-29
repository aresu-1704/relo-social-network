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
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print("Notification tapped: ${response.payload}");
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Setup Firebase message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground message: ${message.notification?.title}");
      _showLocalNotification(message);
    });

    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📩 Opened from background: ${message.notification?.title}");
      // TODO: Navigate based on message data
    });
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'relo_channel',
      'Relo Notifications',
      channelDescription: 'Notifications from Relo social network',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
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
