import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Mock data - replace with API call
  final List<NotificationItem> _allNotifications = [];
  final List<NotificationItem> _friendRequests = [];
  final List<NotificationItem> _interactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.initState();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    // TODO: Call API to get notifications
    await Future.delayed(Duration(seconds: 1));
    
    setState(() {
      // Mock data
      _allNotifications.clear();
      _allNotifications.addAll([
        NotificationItem(
          id: '1',
          type: NotificationType.friendRequest,
          userName: 'Nguyễn Văn A',
          userAvatar: null,
          message: 'đã gửi lời mời kết bạn',
          timestamp: DateTime.now().subtract(Duration(minutes: 5)),
          isRead: false,
        ),
        NotificationItem(
          id: '2',
          type: NotificationType.like,
          userName: 'Trần Thị B',
          userAvatar: null,
          message: 'đã thích bài viết của bạn',
          timestamp: DateTime.now().subtract(Duration(hours: 2)),
          isRead: true,
        ),
        NotificationItem(
          id: '3',
          type: NotificationType.comment,
          userName: 'Lê Văn C',
          userAvatar: null,
          message: 'đã bình luận vào bài viết của bạn',
          timestamp: DateTime.now().subtract(Duration(hours: 5)),
          isRead: true,
        ),
      ]);

      _friendRequests.clear();
      _friendRequests.addAll(_allNotifications.where((n) => 
        n.type == NotificationType.friendRequest));

      _interactions.clear();
      _interactions.addAll(_allNotifications.where((n) => 
        n.type == NotificationType.like || 
        n.type == NotificationType.comment));

      _isLoading = false;
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    setState(() {
      final notification = _allNotifications.firstWhere((n) => n.id == notificationId);
      notification.isRead = true;
    });
    
    // TODO: Call API to mark as read
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var notification in _allNotifications) {
        notification.isRead = true;
      }
    });
    
    // TODO: Call API to mark all as read
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF7C3AED),
        title: Text('Thông báo', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Đánh dấu đã đọc tất cả',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Tất cả (${_allNotifications.length})'),
            Tab(text: 'Kết bạn (${_friendRequests.length})'),
            Tab(text: 'Tương tác (${_interactions.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(_allNotifications),
                _buildNotificationList(_friendRequests),
                _buildNotificationList(_interactions),
              ],
            ),
    );
  }

  Widget _buildNotificationList(List<NotificationItem> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Không có thông báo mới',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: Color(0xFF7C3AED),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 8),
        itemCount: notifications.length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationItem(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification, int index) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        setState(() {
          _allNotifications.remove(notification);
          _friendRequests.remove(notification);
          _interactions.remove(notification);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa thông báo'),
            action: SnackBarAction(
              label: 'Hoàn tác',
              onPressed: () {
                setState(() {
                  _allNotifications.insert(index, notification);
                  if (notification.type == NotificationType.friendRequest) {
                    _friendRequests.add(notification);
                  } else {
                    _interactions.add(notification);
                  }
                });
              },
            ),
          ),
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            _markAsRead(notification.id);
          }
          // TODO: Navigate to relevant screen based on notification type
        },
        child: Container(
          color: notification.isRead ? Colors.white : Color(0xFFF3E5F5),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with notification icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: notification.userAvatar != null
                        ? CachedNetworkImageProvider(notification.userAvatar!)
                        : null,
                    child: notification.userAvatar == null
                        ? Icon(Icons.person, color: Colors.white, size: 28)
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getNotificationColor(notification.type),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        _getNotificationIcon(notification.type),
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: notification.userName,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' ${notification.message}'),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      timeago.format(notification.timestamp, locale: 'vi'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    // Action buttons for friend requests
                    if (notification.type == NotificationType.friendRequest && !notification.isRead)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // TODO: Accept friend request
                                  _markAsRead(notification.id);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF7C3AED),
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  'Chấp nhận',
                                  style: TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // TODO: Reject friend request
                                  _markAsRead(notification.id);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  side: BorderSide(color: Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  'Từ chối',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 10,
                  height: 10,
                  margin: EdgeInsets.only(left: 8, top: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ).animate().slideX(
        begin: 0.2,
        duration: 300.ms,
        delay: (index * 50).ms,
      ).fadeIn(),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.message:
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return Colors.blue;
      case NotificationType.like:
        return Colors.red;
      case NotificationType.comment:
        return Colors.green;
      case NotificationType.message:
        return Color(0xFF7C3AED);
      default:
        return Colors.grey;
    }
  }
}

// Models
enum NotificationType {
  friendRequest,
  like,
  comment,
  message,
  other,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String userName;
  final String? userAvatar;
  final String message;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.userName,
    this.userAvatar,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}
