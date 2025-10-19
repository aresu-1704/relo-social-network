import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/services/message_service.dart';
import 'package:uuid/uuid.dart';

class MessageUtils {
  static Future<void> performSend(
    BuildContext context,
    MessageService messageService,
    Uuid uuid,
    List<Message> messages,
    String conversationId,
    String currentUserId,
    Map<String, dynamic> content,
    Function(List<Message>) updateMessages,
  ) async {
    final tempMessage = Message(
      id: uuid.v4(),
      conversationId: conversationId,
      senderId: currentUserId,
      content: content,
      timestamp: DateTime.now(),
      status: 'pending',
    );

    messages.insert(0, tempMessage);
    updateMessages(List.from(messages));

    try {
      final sentMessage = await messageService.sendMessage(
        conversationId,
        content,
        currentUserId,
      );
      final index = messages.indexWhere((msg) => msg.id == tempMessage.id);
      if (index != -1) {
        messages[index] = sentMessage.copyWith(status: 'sent');
        updateMessages(List.from(messages));
      }
    } catch (_) {
      final index = messages.indexWhere((msg) => msg.id == tempMessage.id);
      if (index != -1) {
        messages[index] = tempMessage.copyWith(status: 'failed');
        updateMessages(List.from(messages));
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gửi tin nhắn thất bại')));
    }
  }
}
