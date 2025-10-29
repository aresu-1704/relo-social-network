import 'package:flutter/material.dart';
import 'package:relo/screen/login_screen.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/services/app_notification_service.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'privacy_settings_screen.dart';

class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  final SecureStorageService storage = const SecureStorageService();
  final UserService userService = ServiceLocator.userService;
  final AuthService authService = ServiceLocator.authService;

  String? _currentUserId;
  User? _currentUser;

  bool _isLoading = true;

  Future<void> _loadCurrentUser() async {
    _currentUserId = await storage.getUserId();
    if (_currentUserId != null) {
      try {
        User? user = await userService.getUserById(_currentUserId!);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentUser = user;
          });
        }
      } catch (e) {
        print('Failed to load user data: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Optionally, set user to null or handle the error state in the UI
            _currentUser = null;
          });
        }
      }
    } else {
      // Handle case where user ID is not found in storage
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF7A2FC0),
        title: Text('Cài đặt', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? _buildShimmerProfile()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: CachedNetworkImageProvider(
                            (_currentUser?.avatarUrl ?? '').isNotEmpty
                                ? _currentUser!.avatarUrl!
                                : 'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w',
                          ),
                          backgroundColor: Colors.grey[300],
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser?.displayName ?? 'Tên người dùng',
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              'Xem trang cá nhân',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Expanded(child: SizedBox(width: 10)),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Đăng xuất'),
                                  content: const Text(
                                    'Bạn có chắc chắn muốn đăng xuất không?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).pop(); // Đóng hộp thoại
                                      },
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          // Lấy device token để logout
                                          final notificationService =
                                              AppNotificationService();
                                          final deviceToken =
                                              await notificationService
                                                  .getDeviceToken();

                                          // Gọi logout với device token
                                          await authService.logout(
                                            deviceToken: deviceToken,
                                          );

                                          if (mounted) {
                                            Navigator.of(context).pop();
                                            Navigator.of(
                                              context,
                                            ).pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    LoginScreen(),
                                              ),
                                              (route) => false,
                                            );
                                          }
                                        } catch (e) {
                                          // Hiển thị lỗi nếu logout thất bại
                                          if (mounted) {
                                            Navigator.of(context).pop();
                                            ShowNotification.showToast(
                                              context,
                                              'Đã xảy ra lỗi, không thể đăng xuất',
                                            );
                                          }
                                        }
                                      },
                                      child: const Text(
                                        'Đăng xuất',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: Icon(
                            Icons.logout_outlined,
                            color: Color(0xFF7A2FC0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(
                  color: Color.fromARGB(255, 207, 205, 205),
                  thickness: 1,
                  height: 1,
                ),

                // Quyền riêng tư & Bảo mật
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PrivacySettingsScreen(userId: _currentUserId!),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18.0,
                      horizontal: 20.0,
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.privacy_tip_outlined,
                          color: Color(0xFF7A2FC0),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quyền riêng tư & Bảo mật',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Đổi mật khẩu, quản lý chặn,...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Xóa tài khoản
                InkWell(
                  onTap: () => _showDeleteAccountDialog(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18.0,
                      horizontal: 20.0,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.delete_forever_outlined, color: Colors.red),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xóa tài khoản',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Xóa vĩnh viễn tài khoản của bạn',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),
              ],
            ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Xóa tài khoản'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Bạn có chắc chắn muốn xóa tài khoản?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                '⚠️ Hành động này sẽ:\n'
                '• Xóa tất cả dữ liệu của bạn\n'
                '• Xóa tất cả bài viết và tin nhắn\n'
                '• Không thể khôi phục lại',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              child: const Text('Xóa tài khoản'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(color: Color(0xFF7A2FC0)),
            SizedBox(width: 20),
            Expanded(child: Text('Đang xóa tài khoản...')),
          ],
        ),
      ),
    );

    try {
      await userService.deleteAccount();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Thành công'),
              ],
            ),
            content: const Text(
              'Tài khoản của bạn đã được xóa.\n\n'
              'Bạn sẽ được đăng xuất ngay bây giờ.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Logout and navigate to login screen
        if (mounted) {
          try {
            // Lấy device token để logout
            final notificationService = AppNotificationService();
            final deviceToken = await notificationService.getDeviceToken();

            // Gọi logout với device token
            await authService.logout(deviceToken: deviceToken);

            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            }
          } catch (e) {
            // Hiển thị lỗi nếu logout thất bại
            if (mounted) {
              ShowNotification.showToast(
                context,
                'Đã xảy ra lỗi, không thể đăng xuất',
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 10),
                Text('Lỗi'),
              ],
            ),
            content: Text('Không thể xóa tài khoản.\n\nLỗi: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildShimmerProfile() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vòng tròn shimmer avatar
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: CircleAvatar(radius: 25, backgroundColor: Colors.white),
              ),
              const SizedBox(width: 16),
              // Shimmer tên & mô tả
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 150,
                        height: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 100,
                        height: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Shimmer cho item setting
          ...List.generate(2, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(height: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
