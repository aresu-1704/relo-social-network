import 'package:flutter/material.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/screen/verify_otp_screen.dart';
import 'package:relo/screen/change_email_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class PrivacySettingsScreen extends StatefulWidget {
  final String userId;
  PrivacySettingsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _PrivacySettingsScreenState createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final UserService _userService = ServiceLocator.userService;
  final List<User> _blockedUsers = [];
  bool _isLoading = true;
  String? _currentUsername;
  String? _currentEmail;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _getCurrentUserInfo();
  }

  Future<void> _getCurrentUserInfo() async {
    final user = await _userService.getUserById(widget.userId);
    setState(() {
      _currentUsername = user.username;
      _currentEmail = user.email;
    });
  }

  Future<void> _loadBlockedUsers() async {
    try {
      setState(() => _isLoading = true);
      final blockedUsers = await _userService.getBlockedUsers(widget.userId);
      setState(() {
        _blockedUsers.clear();
        _blockedUsers.addAll(blockedUsers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      await ShowNotification.showToast(
        context,
        'Không thể tải danh sách người dùng bị chặn',
      );
    }
  }

  Future<void> _unblockUser(String userId, String displayName) async {
    bool? confirm = await ShowNotification.showConfirmDialog(
      context,
      title: 'Bỏ chặn $displayName?',
      confirmText: 'Bỏ chặn',
      cancelText: 'Hủy',
      confirmColor: Color(0xFF7A2FC0),
    );

    if (confirm == true) {
      try {
        await _userService.unblockUser(userId);
        setState(() {
          _blockedUsers.removeWhere((user) => user.id == userId);
        });
        if (mounted) {
          await ShowNotification.showToast(context, 'Đã bỏ chặn $displayName');
        }
      } catch (e) {
        if (mounted) {
          await ShowNotification.showToast(
            context,
            'Không thể bỏ chặn người dùng',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF7A2FC0),
        title: Text('Quyền riêng tư', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF7A2FC0)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blocked users section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 15),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.block, color: Color(0xFF7A2FC0)),
                            SizedBox(width: 10),
                            Text(
                              'Danh sách chặn',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Những người trong danh sách chặn sẽ không thể nhắn tin hoặc xem hồ sơ của bạn',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        SizedBox(height: 20),
                        if (_isLoading)
                          ...List.generate(3, (index) => _buildShimmerItem())
                        else if (_blockedUsers.isEmpty)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Không có người dùng nào bị chặn',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...List.generate(
                            _blockedUsers.length,
                            (index) =>
                                _buildBlockedUserItem(_blockedUsers[index]),
                          ),
                      ],
                    ),
                  ),

                  // Account security
                  Container(
                    margin: EdgeInsets.all(15),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, color: Color(0xFF7A2FC0)),
                            SizedBox(width: 10),
                            Text(
                              'Bảo mật tài khoản',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        ListTile(
                          leading: Icon(Icons.lock_outline, color: Colors.grey),
                          title: Text('Đổi mật khẩu'),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            if (_currentUsername == null) {
                              ShowNotification.showToast(
                                context,
                                'Không thể lấy thông tin tài khoản',
                              );
                              return;
                            }

                            // Chuyển sang màn hình verify OTP (tự động gửi OTP)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VerifyOTPScreen(
                                  identifier: _currentUsername!,
                                  flow: OTPFlow.changePassword,
                                  autoSend: true,
                                ),
                              ),
                            );
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(
                            Icons.email_outlined,
                            color: Colors.grey,
                          ),
                          title: Text('Đổi email'),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            if (_currentEmail == null) {
                              ShowNotification.showToast(
                                context,
                                'Không thể lấy thông tin tài khoản',
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChangeEmailScreen(
                                  userId: widget.userId,
                                  currentEmail: _currentEmail!,
                                ),
                              ),
                            );
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildBlockedUserItem(User user) {
    // Sử dụng cùng logic như messages_screen để xử lý avatar
    final String? avatarUrl = (user.avatarUrl ?? '').isNotEmpty
        ? user.avatarUrl
        : 'assets/none_images/avatar.jpg';

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: avatarUrl!.startsWith('assets/')
            ? AssetImage(avatarUrl)
            : CachedNetworkImageProvider(avatarUrl),
        backgroundColor: Colors.grey[400],
      ),
      title: Text(user.displayName),
      subtitle: Text('@${user.username}'),
      trailing: TextButton(
        onPressed: () => _unblockUser(user.id, user.displayName),
        child: Text('Bỏ chặn', style: TextStyle(color: Color(0xFF7A2FC0))),
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListTile(
        leading: CircleAvatar(radius: 25, backgroundColor: Colors.white),
        title: Container(
          height: 16,
          color: Colors.white,
          margin: EdgeInsets.only(bottom: 8),
        ),
        subtitle: Container(height: 14, width: 100, color: Colors.white),
        trailing: Container(
          width: 70,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
