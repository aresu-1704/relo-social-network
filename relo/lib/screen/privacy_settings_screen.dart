import 'package:flutter/material.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/utils/show_toast.dart';
import 'package:relo/utils/show_alert_dialog.dart';
import 'package:relo/screen/change_password_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  _PrivacySettingsScreenState createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final UserService _userService = ServiceLocator.userService;
  final List<User> _blockedUsers = [];
  bool _isLoading = true;
  
  // Privacy settings - TODO: Load từ backend khi có API
  String _profileVisibility = 'Tất cả mọi người'; // 'Tất cả mọi người', 'Bạn bè', 'Chỉ mình tôi'
  String _avatarVisibility = 'Tất cả mọi người';
  String _coverVisibility = 'Tất cả mọi người';
  String _infoVisibility = 'Bạn bè';

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      // TODO: API để lấy danh sách người dùng bị chặn
      // Hiện tại chưa có API này, cần thêm vào backend
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId, String displayName) async {
    bool? confirm = await showAlertDialog(
      context,
      title: 'Bỏ chặn người dùng',
      message: 'Bạn có chắc chắn muốn bỏ chặn $displayName?',
      confirmText: 'Bỏ chặn',
      cancelText: 'Hủy',
      showCancel: true,
    );

    if (confirm == true) {
      try {
        await _userService.unblockUser(userId);
        setState(() {
          _blockedUsers.removeWhere((user) => user.id == userId);
        });
        if (mounted) {
          await showToast(context, 'Đã bỏ chặn $displayName');
        }
      } catch (e) {
        if (mounted) {
          await showToast(context, 'Không thể bỏ chặn người dùng');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF7C3AED),
        title: Text('Quyền riêng tư', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile visibility settings
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
                            Icon(Icons.visibility, color: Color(0xFF7C3AED)),
                            SizedBox(width: 10),
                            Text(
                              'Hiển thị hồ sơ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        _buildPrivacyOption(
                          'Ai có thể xem ảnh đại diện',
                          _avatarVisibility,
                          Icons.account_circle,
                          (value) => setState(() => _avatarVisibility = value),
                        ),
                        Divider(height: 1),
                        _buildPrivacyOption(
                          'Ai có thể xem ảnh bìa',
                          _coverVisibility,
                          Icons.image,
                          (value) => setState(() => _coverVisibility = value),
                        ),
                        Divider(height: 1),
                        _buildPrivacyOption(
                          'Ai có thể xem thông tin cá nhân',
                          _infoVisibility,
                          Icons.info,
                          (value) => setState(() => _infoVisibility = value),
                        ),
                      ],
                    ),
                  ),

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
                            Icon(Icons.block, color: Color(0xFF7C3AED)),
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
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 20),
                        if (_blockedUsers.isEmpty)
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
                            (index) => _buildBlockedUserItem(_blockedUsers[index]),
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
                            Icon(Icons.security, color: Color(0xFF7C3AED)),
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
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChangePasswordScreen(),
                              ),
                            );
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.devices, color: Colors.grey),
                          title: Text('Quản lý thiết bị đăng nhập'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () async {
                            // TODO: Navigate to device management
                            if (mounted) {
                              await showToast(context, 'Tính năng đang phát triển');
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.history, color: Colors.grey),
                          title: Text('Lịch sử hoạt động'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () async {
                            // TODO: Navigate to activity history
                            if (mounted) {
                              await showToast(context, 'Tính năng đang phát triển');
                            }
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

  Widget _buildPrivacyOption(String title, String value, IconData icon, Function(String) onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () => _showPrivacySelector(title, value, onChanged),
      contentPadding: EdgeInsets.zero,
    );
  }
  
  void _showPrivacySelector(String title, String currentValue, Function(String) onChanged) {
    final options = [
      {'value': 'Tất cả mọi người', 'icon': Icons.public, 'desc': 'Mọi người có thể xem'},
      {'value': 'Bạn bè', 'icon': Icons.people, 'desc': 'Chỉ bạn bè có thể xem'},
      {'value': 'Chỉ mình tôi', 'icon': Icons.lock, 'desc': 'Chỉ bạn có thể xem'},
    ];
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'Chọn ai có thể xem nội dung này',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 20),
            ...options.map((option) => _buildPrivacySelectorOption(
              option['value'] as String,
              option['icon'] as IconData,
              option['desc'] as String,
              currentValue,
              (selected) {
                Navigator.pop(context);
                onChanged(selected);
                // TODO: Gọi API cập nhật khi có backend
                // Real-time update sẽ được thêm sau
                if (mounted) {
                  showToast(context, 'Đã cập nhật cài đặt quyền riêng tư');
                }
              },
            )),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrivacySelectorOption(
    String value,
    IconData icon,
    String description,
    String currentValue,
    Function(String) onSelect,
  ) {
    final isSelected = value == currentValue;
    
    return InkWell(
      onTap: () => onSelect(value),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF7C3AED).withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Color(0xFF7C3AED) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF7C3AED) : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Color(0xFF7C3AED) : Colors.black,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUserItem(User user) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? CachedNetworkImageProvider(user.avatarUrl!)
            : null,
        backgroundColor: Colors.grey[400],
        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
            ? Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(user.displayName),
      subtitle: Text('@${user.username}'),
      trailing: TextButton(
        onPressed: () => _unblockUser(user.id, user.displayName),
        child: Text(
          'Bỏ chặn',
          style: TextStyle(color: Color(0xFF7C3AED)),
        ),
      ),
    );
  }
}
