import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({Key? key}) : super(key: key);

  @override
  _ActivityLogScreenState createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  bool _isLoading = true;
  List<ActivityLog> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    
    // TODO: Call API to get activity logs
    await Future.delayed(Duration(seconds: 1));
    
    setState(() {
      // Mock data
      _activities = [
        ActivityLog(
          id: '1',
          type: ActivityType.login,
          description: 'Đăng nhập từ iPhone 15',
          location: 'Hà Nội, Việt Nam',
          ipAddress: '192.168.1.100',
          timestamp: DateTime.now().subtract(Duration(minutes: 30)),
        ),
        ActivityLog(
          id: '2',
          type: ActivityType.profileUpdate,
          description: 'Cập nhật ảnh đại diện',
          timestamp: DateTime.now().subtract(Duration(hours: 2)),
        ),
        ActivityLog(
          id: '3',
          type: ActivityType.postCreated,
          description: 'Đăng bài viết mới',
          timestamp: DateTime.now().subtract(Duration(hours: 5)),
        ),
        ActivityLog(
          id: '4',
          type: ActivityType.friendAdded,
          description: 'Kết bạn với Nguyễn Văn A',
          timestamp: DateTime.now().subtract(Duration(days: 1)),
        ),
        ActivityLog(
          id: '5',
          type: ActivityType.login,
          description: 'Đăng nhập từ MacBook Pro',
          location: 'Hà Nội, Việt Nam',
          ipAddress: '192.168.1.101',
          timestamp: DateTime.now().subtract(Duration(days: 2)),
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF7C3AED),
        title: Text('Lịch sử hoạt động', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
            tooltip: 'Lọc',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _activities.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadActivities,
                  color: Color(0xFF7C3AED),
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      return _buildActivityItem(_activities[index], index);
                    },
                  ),
                ),
    );
  }

  Widget _buildActivityItem(ActivityLog activity, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getActivityColor(activity.type).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getActivityIcon(activity.type),
                color: _getActivityColor(activity.type),
                size: 24,
              ),
            ),
            
            SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTimestamp(activity.timestamp),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (activity.location != null) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          activity.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (activity.ipAddress != null) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.router,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          'IP: ${activity.ipAddress}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Menu
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Text('Xem chi tiết'),
                  value: 'details',
                ),
                if (activity.type == ActivityType.login)
                  PopupMenuItem(
                    child: Text('Đánh dấu nghi ngờ'),
                    value: 'report',
                  ),
              ],
              onSelected: (value) {
                // Handle menu selection
              },
            ),
          ],
        ),
      ),
    ).animate().slideX(
      begin: 0.2,
      duration: 300.ms,
      delay: (index * 50).ms,
    ).fadeIn();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Chưa có hoạt động nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.login:
        return Icons.login;
      case ActivityType.logout:
        return Icons.logout;
      case ActivityType.profileUpdate:
        return Icons.edit;
      case ActivityType.postCreated:
        return Icons.add_box;
      case ActivityType.postDeleted:
        return Icons.delete;
      case ActivityType.friendAdded:
        return Icons.person_add;
      case ActivityType.friendRemoved:
        return Icons.person_remove;
      case ActivityType.passwordChanged:
        return Icons.lock;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.login:
        return Colors.green;
      case ActivityType.logout:
        return Colors.orange;
      case ActivityType.profileUpdate:
        return Colors.blue;
      case ActivityType.postCreated:
        return Color(0xFF7C3AED);
      case ActivityType.postDeleted:
        return Colors.red;
      case ActivityType.friendAdded:
        return Colors.teal;
      case ActivityType.friendRemoved:
        return Colors.grey;
      case ActivityType.passwordChanged:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lọc theo loại hoạt động',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildFilterOption('Tất cả', true),
              _buildFilterOption('Đăng nhập', false),
              _buildFilterOption('Cập nhật hồ sơ', false),
              _buildFilterOption('Bài viết', false),
              _buildFilterOption('Bạn bè', false),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7C3AED),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Áp dụng', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String label, bool isSelected) {
    return CheckboxListTile(
      title: Text(label),
      value: isSelected,
      activeColor: Color(0xFF7C3AED),
      onChanged: (value) {
        // Handle filter change
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}

// Models
enum ActivityType {
  login,
  logout,
  profileUpdate,
  postCreated,
  postDeleted,
  friendAdded,
  friendRemoved,
  passwordChanged,
  other,
}

class ActivityLog {
  final String id;
  final ActivityType type;
  final String description;
  final String? location;
  final String? ipAddress;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.type,
    required this.description,
    this.location,
    this.ipAddress,
    required this.timestamp,
  });
}
