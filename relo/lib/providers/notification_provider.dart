import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:relo/models/notification.dart';
import 'package:relo/services/websocket_service.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  Timer? _debounceTimer;

  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  NotificationProvider() {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    webSocketService.stream.listen((message) {
      try {
        final data = jsonDecode(message);

        // Handle friend request accepted
        if (data['type'] == 'friend_request_accepted') {
          _handleFriendRequestAccepted(data['payload']);
        }

        // Handle friend added
        if (data['type'] == 'friend_added') {
          _handleFriendAdded(data['payload']);
        }
      } catch (e) {
        debugPrint('Error parsing WebSocket notification: $e');
      }
    });
  }

  void _handleFriendRequestAccepted(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final notification = AppNotification(
      id: 'friend_accepted_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.friendRequestAccepted,
      title: 'Lời mời kết bạn được chấp nhận',
      message:
          '${payload['displayName'] ?? 'Người dùng'} đã chấp nhận lời mời kết bạn của bạn',
      createdAt: DateTime.now(),
      isRead: false,
      metadata: {
        'userId': payload['userId'],
        'displayName': payload['displayName'],
        'username': payload['username'],
        'avatarUrl': payload['avatarUrl'],
      },
    );

    _addNotification(notification);
  }

  void _handleFriendAdded(Map<String, dynamic>? payload) {
    if (payload == null) return;

    final notification = AppNotification(
      id: 'friend_added_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.friendAdded,
      title: 'Đã kết bạn',
      message:
          'Bạn và ${payload['displayName'] ?? 'Người dùng'} đã trở thành bạn bè',
      createdAt: DateTime.now(),
      isRead: false,
      metadata: {
        'userId': payload['userId'],
        'displayName': payload['displayName'],
        'username': payload['username'],
        'avatarUrl': payload['avatarUrl'],
      },
    );

    _addNotification(notification);
  }

  void _addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
