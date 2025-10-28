import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/show_notification.dart';
import '../../services/user_service.dart';

class ProfileComponents {
  // ==== Loading Skeleton ====
  static Widget buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Container(height: 280, color: Colors.white),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Container(height: 20, color: Colors.white),
                SizedBox(height: 10),
                Container(height: 20, width: 200, color: Colors.white),
                SizedBox(height: 20),
                Container(height: 100, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==== Thống kê ====
  static Widget buildStatisticsRow(int friendCount, int postCount) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Bạn bè', friendCount.toString()),
          Container(height: 30, width: 1, color: Colors.grey[300]),
          _buildStatItem('Bài viết', postCount.toString()),
        ],
      ),
    );
  }

  static Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // ==== Nút kết bạn ====
  static Widget buildFriendButton({
    required BuildContext context,
    required bool isFriend,
    required bool hasPendingRequest,
    required dynamic user,
    required UserService userService,
    required Function refreshState,
    Function? onFriendRequestSent,
  }) {
    // Nút chặn luôn hiển thị ở dưới
    final blockButton = ElevatedButton.icon(
      onPressed: () async {
        bool? confirm = await ShowNotification.showConfirmDialog(
          context,
          title: 'Bạn có chắc muốn chặn ${user.displayName}?',
          confirmText: 'Chặn',
          cancelText: 'Hủy',
          confirmColor: Colors.red,
        );

        if (confirm == true) {
          try {
            await userService.blockUser(user.id);
            if (context.mounted) {
              await ShowNotification.showToast(context, 'Đã chặn người dùng');
              // Pop profile screen to go back
              Navigator.pop(context);
            }
          } catch (e) {
            if (context.mounted) {
              await ShowNotification.showToast(
                context,
                'Không thể chặn người dùng',
              );
            }
          }
        }
      },
      icon: Icon(Icons.block, color: Colors.red),
      label: Text('Chặn', style: TextStyle(color: Colors.red)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.red),
        ),
      ),
    );

    if (isFriend) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () =>
                _showFriendOptions(context, user, userService, refreshState),
            icon: Icon(Icons.check, color: Color(0xFF7A2FC0)),
            label: Text('Bạn bè', style: TextStyle(color: Color(0xFF7A2FC0))),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Color(0xFF7A2FC0)),
              ),
            ),
          ),
          SizedBox(height: 10),
          blockButton,
        ],
      );
    } else if (hasPendingRequest) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              // Show confirm dialog
              bool? confirm = await ShowNotification.showConfirmDialog(
                context,
                title: 'Hủy lời mời kết bạn?',
                confirmText: 'Hủy',
                cancelText: 'Không',
                confirmColor: Colors.red,
              );

              if (confirm == true) {
                try {
                  await userService.cancelFriendRequest(user.id);
                  // Call callback to refresh friend status
                  if (onFriendRequestSent != null) {
                    await onFriendRequestSent();
                  }
                } catch (e) {
                  if (context.mounted) {
                    await ShowNotification.showToast(
                      context,
                      'Không thể hủy lời mời',
                    );
                  }
                }
              }
            },
            icon: Icon(Icons.schedule, color: Color(0xFF7A2FC0)),
            label: Text(
              'Đã gửi lời mời',
              style: TextStyle(color: Color(0xFF7A2FC0)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Color(0xFF7A2FC0)),
              ),
            ),
          ),
          SizedBox(height: 10),
          blockButton,
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await userService.sendFriendRequest(user.id);
                // Call callback to refresh friend status
                if (onFriendRequestSent != null) {
                  await onFriendRequestSent();
                }
              } catch (e) {
                if (context.mounted) {
                  await ShowNotification.showToast(
                    context,
                    'Không thể gửi lời mời',
                  );
                }
              }
            },
            icon: Icon(Icons.person_add),
            label: Text('Kết bạn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF7A2FC0),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Color(0xFF7A2FC0)),
              ),
            ),
          ),
          SizedBox(height: 10),
          blockButton,
        ],
      );
    }
  }

  // ==== Menu bạn bè (bottom sheet) ====
  static void _showFriendOptions(
    BuildContext context,
    dynamic user,
    UserService userService,
    Function refreshState,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_remove, color: Colors.red),
              title: Text('Hủy kết bạn', style: TextStyle(color: Colors.red)),
              onTap: () async {
                bool? confirm = await ShowNotification.showConfirmDialog(
                  context,
                  title:
                      'Bạn có chắc muốn hủy kết bạn với ${user.displayName}?',
                  confirmText: 'Hủy kết bạn',
                  cancelText: 'Không',
                  confirmColor: Colors.red,
                );

                if (confirm == true) {
                  try {
                    await userService.unfriendUser(user.id);
                    if (context.mounted) {
                      Navigator.pop(context); // Close bottom sheet
                      refreshState(); // Refresh profile screen
                    }
                  } catch (e) {
                    if (context.mounted) {
                      await ShowNotification.showToast(
                        context,
                        'Không thể hủy kết bạn',
                      );
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.grey),
              title: Text('Hủy'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ==== Info row ====
  static Widget buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey, fontSize: 13)),
                SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
