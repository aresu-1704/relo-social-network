// Màn hình chính với AppBar có thanh tìm kiếm, Bottom Bar, và banner mất kết nối
import 'package:flutter/material.dart';
import 'package:relo/screen/profile_screen.dart';
import 'package:relo/screen/profile_setting_screen.dart';
import 'package:relo/screen/search_screen.dart';
import 'messages_screen.dart';
import 'friends_screen.dart';
import 'newsfeed_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _notificationCount = 3;
  bool _isOffline = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> currentScreens = [
      const NewsFeedScreen(), // Feed (0)
      const FriendsScreen(), // Friends (1)
      MessagesScreen(), // Messages (2) - ở giữa
      Center(child: Text('TODO: Thông báo')), // Notifications (3)
      const ProfileScreen(), // Profile (4)
    ];

    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.black,
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF7A2FC0),
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

      // Dùng Stack để banner nằm trên nội dung
      body: Stack(
        children: [
          currentScreens[_selectedIndex],

          // Banner cảnh báo mất mạng
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isOffline ? 1.0 : 0.0,
            child: _isOffline
                ? Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.wifi_off, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Không có kết nối Internet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),

      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          ConvexAppBar(
            items: [
              TabItem(icon: LucideIcons.home, title: 'Tường nhà'),
              TabItem(icon: LucideIcons.users, title: 'Bạn bè'),
              TabItem(
                icon: Icons.forum_outlined, // Icon chat như Zalo
                title: 'Tin nhắn',
              ), // Giữa
              TabItem(icon: LucideIcons.bell, title: 'Thông báo'),
              TabItem(icon: LucideIcons.user, title: 'Cá nhân'),
            ],
            initialActiveIndex: _selectedIndex,
            onTap: (int i) {
              setState(() {
                _selectedIndex = i;
                if (i == 3) _notificationCount = 0;
              });
            },
            backgroundColor: Colors.grey[100],
            activeColor: const Color(0xFF7A2FC0), // Màu tím khi active
            color: Colors.grey[600], // Màu xám khi không active
            style: TabStyle.flip,
            height: 65,
            curveSize: 100,
            elevation: 10,
          ),
          // Badge cho thông báo (index 3, tính từ bên phải)
          if (_notificationCount > 0)
            Positioned(
              top: 8,
              right:
                  MediaQuery.of(context).size.width *
                  0.18, // Vị trí tab thứ 2 từ phải
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = 3;
                    _notificationCount = 0;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '$_notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
