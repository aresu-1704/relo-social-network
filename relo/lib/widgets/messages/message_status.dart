// file: widgets/message_status.dart
import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';

/// Widget hiển thị trạng thái tin nhắn (Đang gửi, Đã gửi, Đã xem, Gửi thất bại...)
class MessageStatusWidget extends StatelessWidget {
  final Message message;

  const MessageStatusWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    String statusText;
    Color color = Colors.white;
    IconData icon;

    switch (message.status) {
      case 'pending':
        statusText = 'Đang gửi';
        icon = Icons.access_time;
        break;
      case 'failed':
        statusText = 'Gửi thất bại';
        icon = Icons.error_outline;
        break;
      case 'sent':
        statusText = 'Đã gửi';
        icon = Icons.done;
        break;
      default:
        statusText = '';
        color = Colors.transparent;
        icon = Icons.info_outline;
    }

    if (statusText.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 197, 197, 197),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
