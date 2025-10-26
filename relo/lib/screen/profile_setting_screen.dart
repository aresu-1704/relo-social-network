import 'package:flutter/material.dart';
import 'package:relo/screen/login_screen.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/auth_service.dart';

class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({Key? key}) : super(key: key);

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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add more widgets here
                InkWell(
                  onTap: () {
                    //TODO: Mở giao diện trang cá nhân
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
                          backgroundImage: NetworkImage(
                            _currentUser?.avatarUrl ??
                                'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w',
                          ),
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
                                      onPressed: () {
                                        authService.logout();
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
                                        // Đóng hộp thoại
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
                            color: Color(0xFF7C3AED),
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

                // Các tùy chọn cài đặt
                InkWell(
                  onTap: () {
                    // TODO: Mở trang "Tài khoản và bảo mật"
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18.0,
                      horizontal: 20.0,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_outline, color: Color(0xFF7C3AED)),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tài khoản và bảo mật',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Đổi mật khẩu, quản lý thiết bị đăng nhập',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                InkWell(
                  onTap: () {
                    // TODO: Mở trang "Quyền riêng tư"
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
                          color: Color(0xFF7C3AED),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quyền riêng tư',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Quản lý danh sách chặn người dùng',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                InkWell(
                  onTap: () {
                    // TODO: Mở trang "Cài đặt ứng dụng"
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18.0,
                      horizontal: 20.0,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.settings_outlined, color: Color(0xFF7C3AED)),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cài đặt ứng dụng',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Thết lập thông báo, font chữ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
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
}
