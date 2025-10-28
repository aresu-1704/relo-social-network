import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/widgets/messages/message_status.dart';

class AudioMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isPlaying;
  final VoidCallback onPlay;
  final bool isLastFromMe;

  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onPlay,
    required this.isPlaying,
    required this.isLastFromMe,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? (message.status == 'pending'
              ? Colors.grey[300]
              : message.status == 'failed'
              ? Colors.redAccent
              : const Color.fromARGB(255, 165, 85, 240))
        : const Color.fromARGB(255, 255, 255, 255);

    final textColor = isMe ? Colors.white : Colors.black87;
    final timeString =
        "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: message.senderId == 'deleted'
                      ? Colors.grey[300]
                      : null,
                  backgroundImage: message.senderId == 'deleted'
                      ? null
                      : (message.avatarUrl != null &&
                            message.avatarUrl!.isNotEmpty)
                      ? NetworkImage(message.avatarUrl!)
                      : const NetworkImage(
                          'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w',
                        ),
                  child: message.senderId == 'deleted'
                      ? const Icon(
                          Icons.person_off,
                          size: 20,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
            Flexible(
              child: IntrinsicWidth(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
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
                      if (message.senderId == 'deleted' && !isMe)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Text(
                            'Tài khoản không tồn tại',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      // 🔊 Nút play + waveform
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white
                                  : const Color.fromARGB(255, 165, 85, 240),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: isMe
                                    ? const Color.fromARGB(255, 165, 85, 240)
                                    : Colors.white,
                                size: 18,
                              ),
                              onPressed: onPlay,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.graphic_eq,
                            color: isMe
                                ? Colors.white70
                                : const Color.fromARGB(255, 165, 85, 240),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tin nhắn thoại',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeString,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        isMe && isLastFromMe
            ? Padding(
                padding: const EdgeInsets.only(top: 1, right: 0),
                child: MessageStatusWidget(message: message),
              )
            : const SizedBox(height: 4),
      ],
    );
  }
}
