import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:relo/models/notification.dart' as models;
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';

class NotificationProvider extends ChangeNotifier {
  final List<models.Notification> _notifications = [];
  Timer? _debounceTimer;
  StreamSubscription? _webSocketSubscription;
  String? _currentUserId;

  List<models.Notification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  NotificationProvider() {
    debugPrint('🏗️ NotificationProvider: Constructor called');
    _init();
  }

  Future<void> _init() async {
    debugPrint('🔧 NotificationProvider: Initializing...');
    await _loadCurrentUserId();
    debugPrint('👤 NotificationProvider: Current user ID: $_currentUserId');
    _loadNotifications();
    _listenToWebSocket();
    debugPrint('✅ NotificationProvider: Initialization complete');
  }

  Future<void> _loadCurrentUserId() async {
    final storage = const SecureStorageService();
    _currentUserId = await storage.getUserId();
  }

  Future<void> _loadNotifications() async {
    try {
      debugPrint('🔄 Loading notifications from API...');
      final fetchedNotifications = await ServiceLocator.notificationService
          .getNotifications();
      debugPrint('📦 Fetched ${fetchedNotifications.length} notifications');
      for (var notif in fetchedNotifications) {
        debugPrint(
          '  - Type: ${notif.type}, Title: ${notif.title}, Message: ${notif.message}',
        );
      }
      _notifications.clear();
      _notifications.addAll(fetchedNotifications);
      notifyListeners();
      debugPrint('✅ Total notifications in list: ${_notifications.length}');
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
    }
  }

  void _listenToWebSocket() {
    debugPrint('👂 NotificationProvider: Setting up WebSocket listener');
    _webSocketSubscription?.cancel(); // Cancel old subscription if exists
    _webSocketSubscription = ServiceLocator.websocketService.stream.listen((
      message,
    ) {
      debugPrint(
        '📩 NotificationProvider received WebSocket message: $message',
      );
      try {
        final data = jsonDecode(message);

        // Handle friend request received
        if (data['type'] == 'friend_request_received') {
          debugPrint('✅ Friend request received, adding notification');
          _handleFriendRequestReceived(data['payload']);
        }

        // Handle friend request accepted
        if (data['type'] == 'friend_request_accepted') {
          _handleFriendRequestAccepted(data['payload']);
        }

        // Handle friend added
        if (data['type'] == 'friend_added') {
          _handleFriendAdded(data['payload']);
        }

        // Handle post reaction
        if (data['type'] == 'post_reaction') {
          _handlePostReaction(data['payload']);
        }

        // Handle new post - không xử lý realtime vì không có notification ID
        // Chỉ reload từ database khi vào màn hình notifications
        // if (data['type'] == 'new_post') {
        //   _handleNewPost(data['payload']).catchError((e) {
        //     debugPrint('Error handling new post notification: $e');
        //   });
        // }
      } catch (e) {
        debugPrint('Error parsing WebSocket message: $e');
      }
    });
  }

  void _handleFriendRequestReceived(Map<String, dynamic>? payload) {
    debugPrint('🔔 _handleFriendRequestReceived called with payload: $payload');
    // Realtime: Add notification to the top of the list khi nhận được lời mời kết bạn
    if (payload != null) {
      final notification = models.Notification(
        id: payload['id'] ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: _currentUserId ?? '',
        type: 'friend_request',
        title: 'Lời mời kết bạn',
        message:
            '${payload['displayName'] ?? 'Người dùng'} muốn kết bạn với bạn',
        metadata: payload,
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
      );
      _notifications.insert(0, notification);
      notifyListeners();
      debugPrint(
        '✅ Notification added to list. Total notifications: ${_notifications.length}',
      );
    } else {
      debugPrint('❌ Payload is null');
    }
  }

  void _handleFriendRequestAccepted(Map<String, dynamic>? payload) {
    // Realtime: Add notification to the top of the list
    if (payload != null) {
      final notification = models.Notification(
        id: payload['id'] ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: payload['userId'] ?? '',
        type: 'friend_request_accepted',
        title: 'Đã chấp nhận lời mời kết bạn',
        message:
            '${payload['displayName'] ?? 'Người dùng'} đã chấp nhận lời mời kết bạn của bạn',
        metadata: payload,
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
      );
      _notifications.insert(0, notification);
      notifyListeners();
    }
  }

  void _handleFriendAdded(Map<String, dynamic>? payload) {
    // Realtime: Add notification to the top of the list
    if (payload != null) {
      final notification = models.Notification(
        id: payload['id'] ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: payload['userId'] ?? '',
        type: 'friend_added',
        title: 'Đã kết bạn',
        message:
            'Bạn và ${payload['displayName'] ?? 'Người dùng'} đã trở thành bạn bè',
        metadata: payload,
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
      );
      _notifications.insert(0, notification);
      notifyListeners();
    }
  }

  void _handlePostReaction(Map<String, dynamic>? payload) {
    // Realtime: Add notification to the top of the list
    if (payload != null) {
      final notification = models.Notification(
        id: payload['id'] ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: payload['userId'] ?? '',
        type: 'post_reaction',
        title: 'Có người thích bài viết của bạn',
        message:
            '${payload['userDisplayName'] ?? 'Người dùng'} đã thích bài viết của bạn',
        metadata: payload,
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
      );
      _notifications.insert(0, notification);
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await ServiceLocator.notificationService.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = models.Notification(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          type: _notifications[index].type,
          title: _notifications[index].title,
          message: _notifications[index].message,
          metadata: _notifications[index].metadata,
          isRead: true,
          createdAt: _notifications[index].createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ServiceLocator.notificationService.markAllAsRead();
      await _loadNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await ServiceLocator.notificationService.deleteNotification(
        notificationId,
      );
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadNotifications();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _webSocketSubscription?.cancel();
    super.dispose();
  }
}
