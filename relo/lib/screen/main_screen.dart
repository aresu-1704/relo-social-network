// Màn hình chính với AppBar có thanh tìm kiếm và Bottom Bar được tùy chỉnh
import 'package:flutter/material.dart';
import 'package:relo/screen/profile_screen.dart';
import 'package:relo/screen/profile_setting_screen.dart';
import 'package:relo/screen/search_screen.dart';
import 'messages_screen.dart';
import 'friends_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _notificationCount = 3; // TODO: Lấy số thông báo thực tế

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Cập nhật lại body để sử dụng _buildProfileScreen cho tab cá nhân
    final List<Widget> currentScreens = [
      MessagesScreen(),
      Center(child: Text('TODO: Tường nhà')),
      const FriendsScreen(),
      Center(child: Text('TODO: Thông báo')),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.black,
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF7A2FC0),
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 31,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
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
            // Settings button - Only show in Profile tab
            if (_selectedIndex == 4)
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingScreen(),
                    ),
                  );
                },
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
            top: BorderSide(
              color: Colors.grey[300]!,
              width: 0.5,
            ), // Viền trên mỏng
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Color(0xFF7A2FC0),
          unselectedItemColor: Colors.grey, // Màu icon chưa chọn là xám
          backgroundColor: Colors
              .transparent, // Nền trong suốt để màu của container hiển thị
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
              icon: Icon(LucideIcons.messageCircle),
              label: 'Tin nhắn',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutGrid),
              label: 'Tường nhà',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.users),
              label: 'Bạn bè',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  Icon(LucideIcons.bell),
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
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
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
              icon: Icon(LucideIcons.user),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}
