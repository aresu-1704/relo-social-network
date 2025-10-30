import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationMessageBubble extends StatelessWidget {
  final Map<String, dynamic> content;
  final DateTime timestamp;

  const NotificationMessageBubble({
    super.key,
    required this.content,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final String notificationType = content['notification_type'] ?? '';
    final String text = content['text'] ?? '';

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIcon(notificationType),
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  IconData _getIcon(String notificationType) {
    switch (notificationType) {
      case 'name_changed':
        return Icons.edit_outlined;
      case 'avatar_changed':
        return Icons.image_outlined;
      case 'member_left':
        return Icons.logout;
      case 'member_added':
        return Icons.person_add;
      default:
        return Icons.info_outline;
    }
  }
}
