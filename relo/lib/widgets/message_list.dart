import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/widgets/audio_message_bubble.dart';
import 'package:relo/widgets/media_message_bubble.dart';
import 'package:relo/widgets/text_message_bubble.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;
  final String currentUserId;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final String? currentlyPlayingUrl;
  final void Function(String url) onPlayAudio;
  final void Function(Message message) onMessageLongPress;

  const MessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.currentlyPlayingUrl,
    required this.onPlayAudio,
    required this.onMessageLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text("Chưa có tin nhắn nào, hãy gửi một lời chào"),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.all(8.0),
      itemCount: messages.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (isLoadingMore && index == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final message = messages[index];
        final isMe = message.senderId == currentUserId;
        final previousMessage = index + 1 < messages.length
            ? messages[index + 1]
            : null;

        final widgets = <Widget>[];

        // Hiển thị timestamp nếu cách nhau >= 1 giờ
        if (_shouldShowTimestamp(message, previousMessage)) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 197, 197, 197),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatTimestamp(message.timestamp),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ),
          );
        }

        final messageType = message.content['type'];
        if (messageType == 'audio') {
          final url = message.content['url'];
          final isPlaying = currentlyPlayingUrl == url;

          widgets.add(
            AudioMessageBubble(
              message: message,
              isMe: isMe,
              isPlaying: isPlaying,
              onPlay: () => onPlayAudio(url),
              isLastFromMe: _isLastFromUser(messages, index, currentUserId),
            ),
          );
        } else if (messageType == 'media') {
          widgets.add(
            MediaMessageBubble(
              message: message,
              isMe: isMe,
              isLastFromMe: _isLastFromUser(messages, index, currentUserId),
            ),
          );
        } else {
          widgets.add(
            TextMessageBubble(
              message: message,
              isMe: isMe,
              isLastFromMe: _isLastFromUser(messages, index, currentUserId),
            ),
          );
        }

        return GestureDetector(
          onLongPress: () => onMessageLongPress(message),
          child: Column(children: widgets),
        );
      },
    );
  }

  bool _shouldShowTimestamp(Message current, Message? previous) {
    if (previous == null) return true;
    final diff = current.timestamp.difference(previous.timestamp);
    return diff.inMinutes >= 60;
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    } else {
      return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.day}/${time.month}/${time.year}";
    }
  }

  bool _isLastFromUser(List<Message> messages, int index, String userId) {
    return messages[index].senderId == userId &&
        (index == 0 || messages[index - 1].senderId != userId);
  }
}
