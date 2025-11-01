import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/app_notification_service.dart';

class MessageProvider extends ChangeNotifier {
  int _unreadConversationCount = 0;
  StreamSubscription? _webSocketSubscription;
  String? _currentUserId;
  Timer? _debounceTimer;

  int get unreadConversationCount => _unreadConversationCount;

  bool get hasUnread => _unreadConversationCount > 0;

  MessageProvider() {
    _init();
  }

  Future<void> _init() async {
    await _getCurrentUserId();
    await _loadUnreadCount();
    _listenToWebSocket();
  }

  Future<void> _getCurrentUserId() async {
    final secureStorage = const SecureStorageService();
    _currentUserId = await secureStorage.getUserId();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final messageService = ServiceLocator.messageService;
      final conversations = await messageService.fetchConversations();

      if (_currentUserId == null) {
        _unreadConversationCount = 0;
        notifyListeners();
        return;
      }

      int unreadCount = 0;
      for (var conversation in conversations) {
        final seenIds = List<String>.from(conversation['seenIds'] ?? []);
        if (!seenIds.contains(_currentUserId)) {
          unreadCount++;
        }
      }

      _unreadConversationCount = unreadCount;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading unread conversation count: $e');
    }
  }

  void _listenToWebSocket() {
    _webSocketSubscription?.cancel();
    _webSocketSubscription = ServiceLocator.websocketService.stream.listen((
      message,
    ) {
      try {
        final data = jsonDecode(message);

        // Handle new message
        if (data['type'] == 'new_message') {
          _handleNewMessage(data['payload']);
        }

        // Handle conversation seen/read
        if (data['type'] == 'conversation_seen') {
          _handleConversationSeen(data['payload']);
        }
      } catch (e) {
        debugPrint('Error handling WebSocket message in MessageProvider: $e');
      }
    });
  }

  void _handleNewMessage(Map<String, dynamic>? payload) async {
    if (payload == null || _currentUserId == null) return;

    final conversationData = payload['conversation'];
    if (conversationData == null) return;

    final seenIds = List<String>.from(conversationData['seenIds'] ?? []);

    // Kiểm tra nếu tin nhắn từ chính mình thì không tăng unread count
    final messageData = payload['message'];
    if (messageData != null && messageData['senderId'] == _currentUserId) {
      return;
    }

    final conversationId = conversationData['id'] as String?;
    final messageContent = messageData['content'] as Map<String, dynamic>?;
    final contentType = messageData['content']?['type'] as String? ?? 'text';
    final senderName =
        messageData['senderName'] as String? ??
        conversationData['senderName'] as String? ??
        'Người dùng';
    final senderAvatar =
        messageData['avatarUrl'] as String? ??
        conversationData['avatarUrl'] as String?;

    // Hiển thị notification nếu conversation chưa được đọc
    // (nghĩa là user không đang ở trong conversation đó)
    if (!seenIds.contains(_currentUserId) && conversationId != null) {
      // Hiển thị local notification khi app ở foreground
      await _showMessageNotification(
        conversationId: conversationId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        contentType: contentType,
        messageContent: messageContent,
      );
    }

    // Nếu conversation chưa được đọc (chưa có currentUserId trong seenIds)
    if (!seenIds.contains(_currentUserId)) {
      // Debounce để tránh reload quá nhiều lần khi có nhiều tin nhắn liên tiếp
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _loadUnreadCount();
      });
    }
  }

  Future<void> _showMessageNotification({
    required String conversationId,
    required String senderName,
    String? senderAvatar,
    required String contentType,
    Map<String, dynamic>? messageContent,
  }) async {
    try {
      final notificationService = AppNotificationService();

      // Format message content
      String body;
      switch (contentType) {
        case 'audio':
          body = '🎤 [Tin nhắn thoại]';
          break;
        case 'media':
          body = '🖼️ [Đa phương tiện]';
          break;
        case 'file':
          body = '📁 [Tệp tin]';
          break;
        case 'delete':
          body = '[Tin nhắn đã bị thu hồi]';
          break;
        default:
          body = messageContent?['text'] as String? ?? 'Đã gửi tin nhắn';
      }

      // Hiển thị notification
      await notificationService.showNotification(
        title: senderName,
        body: body,
        payload: jsonEncode({
          'conversation_id': conversationId,
          'type': 'message',
        }),
        senderName: senderName,
        senderAvatarUrl: senderAvatar,
        conversationId: conversationId,
        hasReply: true,
      );
    } catch (e) {
      debugPrint('Error showing message notification: $e');
    }
  }

  void _handleConversationSeen(Map<String, dynamic>? payload) {
    if (payload == null || _currentUserId == null) return;

    final conversationId = payload['conversationId'];
    if (conversationId == null) return;

    // Khi một conversation được đánh dấu là đã đọc, reload count
    _loadUnreadCount();
  }

  // Gọi method này khi user vào MessagesScreen để reload count
  Future<void> refresh() async {
    await _getCurrentUserId();
    await _loadUnreadCount();
  }

  // Reset unread count khi user đã vào MessagesScreen (đã xem rồi)
  void markAllAsSeen() {
    _unreadConversationCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
