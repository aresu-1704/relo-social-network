// Màn hình chính với AppBar có thanh tìm kiếm và Bottom Bar được tùy chỉnh
import 'package:flutter/material.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/screen/default_screen.dart';
import 'messages_screen.dart';
import 'friends_screen.dart';

// TODO: Thêm các màn hình con vào list này
final List<Widget> screens = [
  MessagesScreen(),
  Center(child: Text('TODO: Tường nhà')), // Placeholder for Home Screen
  const FriendsScreen(), // Placeholder for Friends Screen
  Center(
    child: Text('TODO: Thông báo'),
  ), // Placeholder for Notifications Screen
  Center(child: Text('TODO: Cá nhân')), // Placeholder for Profile Screen
];

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _notificationCount = 3; // TODO: Lấy số thông báo thực tế
  final AuthService _authService = AuthService();

  // Màu tím chủ đạo
  final Color primaryColor = Color(0xFF7C3AED);

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Màn hình cá nhân với nút logout
  Widget _buildProfileScreen() {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          // Ngắt kết nối WebSocket
          webSocketService.disconnect();

          // Gọi hàm logout của AuthService để xóa tokens an toàn
          await _authService.logout();

          // Chuyển về màn hình đăng nhập
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DefaultScreen()),
              (route) => false,
            );
          }
        },
        child: Text('Đăng xuất'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cập nhật lại body để sử dụng _buildProfileScreen cho tab cá nhân
    final List<Widget> currentScreens = [
      MessagesScreen(),
      Center(child: Text('TODO: Tường nhà')), 
      const FriendsScreen(), 
      Center(child: Text('TODO: Thông báo')), 
      _buildProfileScreen(), // Sử dụng widget profile ở đây
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF7A2FC0),
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 31,
                child: GestureDetector(
                  onTap: () => {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DefaultScreen()),
                    ), //TODO: Làm màn hình tìm kiếm
                  },
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.white70),
                      SizedBox(width: 12),
                      Text(
                        'Tìm kiếm',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => {},
              icon: Icon(Icons.settings, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: currentScreens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100], // Màu nền xám
          border: Border(
            top: BorderSide(color: Colors.grey[300]!, width: 0.5), // Viền trên mỏng
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey, // Màu icon chưa chọn là xám
          backgroundColor: Colors.transparent, // Nền trong suốt để màu của container hiển thị
          elevation: 0, // Bỏ shadow mặc định
          type: BottomNavigationBarType.fixed, // Giữ các item cố định
          showSelectedLabels: true,
          showUnselectedLabels: false,
          onTap: (int i) {
            setState(() {
              _selectedIndex = i;
              if (i == 3) {
                _notificationCount = 0;
              }
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Tin nhắn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined),
              label: 'Tường nhà',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              label: 'Bạn bè',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  Icon(Icons.notifications_none),
                  if (_notificationCount > 0)
                    Positioned(
                      top: 0,
                      right: 4,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$_notificationCount',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Thông báo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}