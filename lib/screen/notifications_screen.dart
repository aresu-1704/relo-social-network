import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:relo/providers/notification_provider.dart';
import 'package:relo/models/notification.dart' as models;
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có thông báo',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.refresh();
            },
            child: ListView.builder(
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                return _buildNotificationItem(context, notification, provider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    models.Notification notification,
    NotificationProvider provider,
  ) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: () {
        if (isUnread) {
          provider.markAsRead(notification.id);
        }

        // Navigate based on notification type
        final metadata = notification.metadata;

        if (metadata['userId'] != null &&
            (notification.type == 'friend_request_accepted' ||
                notification.type == 'friend_added')) {
          // Navigate to user profile
          // You can implement this later
        } else if (metadata['postId'] != null &&
            notification.type == 'new_post') {
          // Navigate to post
          // You can implement this later
        }
      },
      child: Container(
        color: isUnread ? const Color(0xFFF9F9F9) : Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _getNotificationIconColor(
                notification.type,
              ).withOpacity(0.1),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: _getNotificationIconColor(notification.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(notification.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () {
                provider.deleteNotification(notification.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request_accepted':
      case 'friend_request_rejected':
        return Icons.person_add_rounded;
      case 'friend_added':
        return Icons.people_rounded;
      case 'new_post':
        return Icons.article_rounded;
      case 'post_reaction':
        return Icons.favorite_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationIconColor(String type) {
    switch (type) {
      case 'friend_request_accepted':
      case 'friend_request_rejected':
        return Colors.blue;
      case 'friend_added':
        return Colors.green;
      case 'new_post':
        return Colors.purple;
      case 'post_reaction':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Vừa xong';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} phút trước';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM/yyyy').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }
}
