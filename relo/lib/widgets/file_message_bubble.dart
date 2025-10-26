import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/widgets/message_status.dart';
import 'package:filesize/filesize.dart'; // Need to add this dependency

class FileMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isLastFromMe;

  const FileMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isLastFromMe,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = message.status == 'pending';
    final isFailed = message.status == 'failed';

    final bubbleColor = isMe
        ? (isPending
              ? const Color(0xFFA555F0).withOpacity(0.2)
              : isFailed
              ? Colors.grey[700]
              : const Color(0xFFA555F0))
        : Colors.white;

    final textColor = isMe ? Colors.white : Colors.black87;

    final timeString =
        "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";

    final fileName = message.content['fileName'] ?? 'File';
    final fileSize = message.content['fileSize'] ?? 0;

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
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
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
                  child: InkWell(
                    onTap: () {
                      // TODO: Implement file download/open
                    },
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: textColor,
                                size: 40,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      filesize(fileSize),
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeString,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              isMe && isLastFromMe
                  ? Padding(
                      padding: const EdgeInsets.only(top: 1, right: 0),
                      child: MessageStatusWidget(message: message),
                    )
                  : const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}
