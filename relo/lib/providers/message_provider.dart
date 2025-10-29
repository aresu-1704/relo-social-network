import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';

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
    _webSocketSubscription = webSocketService.stream.listen((message) {
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

  void _handleNewMessage(Map<String, dynamic>? payload) {
    if (payload == null || _currentUserId == null) return;

    final conversationData = payload['conversation'];
    if (conversationData == null) return;

    final seenIds = List<String>.from(conversationData['seenIds'] ?? []);

    // Kiểm tra nếu tin nhắn từ chính mình thì không tăng unread count
    final messageData = payload['message'];
    if (messageData != null && messageData['senderId'] == _currentUserId) {
      return;
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
