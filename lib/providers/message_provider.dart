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

    // KHÔNG hiển thị local notification từ WebSocket khi app đang mở
    // Chỉ hiển thị notification khi app ở background/terminated (từ FCM)
    // Notification sẽ được xử lý bởi Firebase background handler
    debugPrint(
      '📱 New message via WebSocket - not showing notification (app is foreground)',
    );

    // Nếu conversation chưa được đọc (chưa có currentUserId trong seenIds)
    if (!seenIds.contains(_currentUserId)) {
      // Debounce để tránh reload quá nhiều lần khi có nhiều tin nhắn liên tiếp
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _loadUnreadCount();
      });
    }
  }

  Future<void> _showMessageNotification(
    Map<String, dynamic>? messageData,
    Map<String, dynamic> conversationData,
    String conversationId,
  ) async {
    if (messageData == null) return;

    // Kiểm tra nếu đang ở màn hình chat của conversation này thì không hiển thị
    // Note: Đơn giản hóa - sẽ hiển thị notification, user có thể bỏ qua nếu đang ở màn hình chat
    // Vì việc kiểm tra route chính xác phức tạp và không cần thiết

    try {
      final notificationService = AppNotificationService();

      // Lấy thông tin sender
      final senderId = messageData['senderId'] as String?;
      if (senderId == null || senderId == _currentUserId) return;

      // Lấy thông tin conversation
      final isGroup = conversationData['isGroup'] as bool? ?? false;

      // Ưu tiên lấy senderName từ message_data (backend đã gửi sẵn)
      String senderName = messageData['senderName'] as String? ?? 'Người dùng';
      String? senderAvatar = messageData['avatarUrl'] as String?;

      // Nếu không có senderName trong message_data, thử lấy từ participantsInfo
      if (senderName == 'Người dùng') {
        final participantsInfo = conversationData['participantsInfo'] as List?;
        if (participantsInfo != null) {
          for (var p in participantsInfo) {
            if (p is Map && p['userId'] == senderId) {
              senderName = p['displayName'] as String? ?? 'Người dùng';
              if (senderAvatar == null) {
                senderAvatar = p['avatarUrl'] as String?;
              }
              break;
            }
          }
        }
      }

      // Nếu vẫn không tìm thấy, thử từ participants
      if (senderName == 'Người dùng') {
        final participants = List<Map<String, dynamic>>.from(
          conversationData['participants'] ?? [],
        );
        for (var p in participants) {
          if (p['userId'] == senderId) {
            senderName = p['displayName'] as String? ?? 'Người dùng';
            if (senderAvatar == null) {
              senderAvatar = p['avatarUrl'] as String?;
            }
            break;
          }
        }
      }

      // Nếu vẫn không tìm thấy, fetch từ UserService (fallback)
      if (senderName == 'Người dùng') {
        try {
          debugPrint('📱 Fetching user info for senderId: $senderId');
          final userService = ServiceLocator.userService;
          final user = await userService.getUserById(senderId);
          senderName = user.displayName.isNotEmpty
              ? user.displayName
              : (user.username.isNotEmpty ? user.username : 'Người dùng');
          if (senderAvatar == null) {
            senderAvatar = user.avatarUrl;

            debugPrint('📱 Found user: $senderName, avatar: $senderAvatar');
          } else {
            debugPrint('📱 User not found for senderId: $senderId');
          }
        } catch (e) {
          debugPrint('Error fetching user info for notification: $e');
        }
      }

      // Nếu là nhóm và không tìm thấy sender name, dùng tên nhóm
      if (senderName == 'Người dùng' && isGroup) {
        final groupName = conversationData['name'] as String?;
        if (groupName != null && groupName.isNotEmpty) {
          senderName = groupName;
        } else {
          senderName = 'Nhóm chat';
        }
      }

      // Format message content
      final content = messageData['content'] as Map<String, dynamic>?;
      String messageText = '';
      String contentType = 'text';

      if (content != null) {
        contentType = content['type'] as String? ?? 'text';
        switch (contentType) {
          case 'text':
            messageText = content['text'] as String? ?? '';
            break;
          case 'audio':
            messageText = '🎤 [Tin nhắn thoại]';
            break;
          case 'media':
            messageText = '🖼️ [Đa phương tiện]';
            break;
          case 'file':
            messageText = '📁 [Tệp tin]';
            break;
          default:
            messageText = 'Đã gửi tin nhắn';
        }
      }

      // Format title - dùng tên nhóm nếu là nhóm, không thì dùng senderName
      final String title = isGroup
          ? (conversationData['name'] as String? ?? senderName)
          : senderName;

      // Lấy thông tin conversation để thêm vào payload (cho navigation)
      final participants = List<Map<String, dynamic>>.from(
        conversationData['participants'] ?? [],
      );
      final memberIds = participants
          .map((p) => (p['userId']?.toString() ?? p['id']?.toString() ?? ''))
          .where((id) => id.isNotEmpty)
          .toList();

      debugPrint(
        '📱 Showing notification - Title: $title, Body: $messageText, SenderName: $senderName, Avatar: $senderAvatar',
      );

      // Tạo payload với đầy đủ thông tin để navigate đúng ChatScreen
      final payload = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_avatar': senderAvatar ?? '',
        'content_type': contentType,
        'has_reply': 'true',
        'is_group': isGroup.toString(),
        'chat_name': title,
        'avatar_url': isGroup
            ? (conversationData['avatarUrl'] as String? ?? '')
            : (senderAvatar ?? ''),
        'member_ids': memberIds.join(','),
        'member_count': participants.length.toString(),
      };

      // Tạo payload JSON string đúng format
      final payloadString = jsonEncode(payload);

      debugPrint('📱 Notification payload: $payloadString');

      // Hiển thị notification với avatar và MessagingStyle
      await notificationService.showNotification(
        title: title,
        body: messageText.isNotEmpty ? messageText : 'Đã gửi tin nhắn',
        payload: payloadString,
        senderAvatarUrl: senderAvatar,
        senderName: senderName,
        conversationId: conversationId,
        hasReply: true,
      );

      debugPrint('📱 Notification shown successfully');
    } catch (e) {
      debugPrint('Error in _showMessageNotification: $e');
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
