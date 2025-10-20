import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';

class TextMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const TextMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = message.status == 'pending';
    final isFailed = message.status == 'failed';

    // 🎨 Màu bong bóng
    final bubbleColor = isMe
        ? (isPending
              ? Colors.grey[400]
              : isFailed
              ? Colors.red[400]
              : const Color(0xFFA555F0))
        : Colors.white;

    final textColor = isMe ? Colors.white : Colors.black87;

    // 🕓 Giờ gửi
    final timeString =
        "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
                  ? NetworkImage(message.avatarUrl!)
                  : const NetworkImage(
                      'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w',
                    ),
            ),
          ),
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe
                    ? const Radius.circular(16)
                    : const Radius.circular(4),
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 💬 Nội dung
                Text(
                  message.content['text'] ?? '',
                  style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
                ),
                const SizedBox(height: 4),
                // 🕓 Giờ + Icon trạng thái
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                    if (isMe && (isPending || isFailed)) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isPending ? Icons.access_time : Icons.error_outline,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
