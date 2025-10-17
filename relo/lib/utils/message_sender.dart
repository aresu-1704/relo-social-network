import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/message_database.dart';
import '../services/message_service.dart';
import '../models/message.dart';

class MessageSender {
  final MessageService _messageService;
  Timer? _retryTimer;

  MessageSender(this._messageService);

  /// Gửi tin nhắn lần đầu
  Future<Message> sendMessage(
    String conversationId,
    Map<String, dynamic> content,
    String senderId,
  ) async {
    // Tạo message pending và lưu local
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderId: senderId,
      conversationId: conversationId,
      timestamp: DateTime.now(),
      status: 'pending',
    );

    await MessageDatabase.instance.create(message);

    // Gửi lên server
    _attemptSend(message);

    return message;
  }

  /// Thử gửi tin nhắn lên server
  Future<void> _attemptSend(Message message) async {
    try {
      final sentMessage = await _messageService.sendMessage(
        message.conversationId,
        message.content,
        message.senderId,
      );

      final updated = message.copyWith(
        id: sentMessage.id,
        timestamp: sentMessage.timestamp,
        status: 'sent',
      );

      await MessageDatabase.instance.update(updated);
    } catch (_) {
      // Nếu thất bại, đánh dấu failed
      final failedMessage = message.copyWith(status: 'failed');
      await MessageDatabase.instance.update(failedMessage);
    }
  }

  /// Bắt đầu tự động retry các tin nhắn pending/failed
  void startAutoRetry({Duration interval = const Duration(seconds: 5)}) {
    _retryTimer ??= Timer.periodic(interval, (_) async {
      // Kiểm tra kết nối mạng
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) return;

      // Lấy danh sách tin nhắn pending/failed
      final pending = await MessageDatabase.instance.readPendingMessages();
      for (final msg in pending) {
        _attemptSend(msg);
      }

      final failed = await MessageDatabase.instance.readFailedMessages();
      for (final msg in failed) {
        _attemptSend(
          msg.copyWith(status: 'pending'),
        ); // đổi thành pending để retry
      }
    });
  }

  /// Dừng retry
  void stopAutoRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
