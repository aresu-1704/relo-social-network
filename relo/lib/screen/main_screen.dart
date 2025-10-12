// Màn hình chính với AppBar có thanh tìm kiếm và Convex Bottom Bar
import 'package:flutter/material.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:relo/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:relo/screen/default_screen.dart';

// TODO: Thêm các màn hình con vào list này
final List<Widget> screens = [
  // ...TODO
];

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _notificationCount = 3; // TODO: Lấy số thông báo thực tế

  // Màu tím chủ đạo
  final Color primaryColor = Color(0xFF7C3AED); // Đổi mã màu tím nếu bạn muốn

  // Màn hình cá nhân với nút logout
  Widget _buildProfileScreen() {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          // Ngắt kết nối WebSocket
          webSocketService.disconnect();
          // Xóa token đăng nhập
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          // Gọi hàm logout của AuthService nếu cần
          AuthService().logout();
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
                      MaterialPageRoute(builder: (_) => const DefaultScreen()),
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
              icon: Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ),
      body: screens.isNotEmpty
          ? screens[_selectedIndex]
          : (_selectedIndex == 4
                ? _buildProfileScreen()
                : Center(child: Text('TODO: Thêm màn hình con'))), // TODO
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.black,
        onTap: (int i) {
          setState(() {
            _selectedIndex = i;
            if (i == 3) {
              _notificationCount =
                  0; // Clear notification badge when "Thông báo" is tapped
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
    );
  }
}
