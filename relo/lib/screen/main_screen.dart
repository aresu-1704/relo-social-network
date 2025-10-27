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
      MessagesScreen(),
      const NewsFeedScreen(),
      const MessagesScreen(),
      const FriendsScreen(),
      Center(child: Text('TODO: Thông báo')),
      const ProfileScreen(),
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

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF7A2FC0),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          onTap: (int i) {
            setState(() {
              _selectedIndex = i;
              if (i == 3) _notificationCount = 0;
            });
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.messageCircle),
              label: 'Tin nhắn',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutGrid),
              label: 'Tường nhà',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.users),
              label: 'Bạn bè',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(LucideIcons.bell),
                  if (_notificationCount > 0)
                    Positioned(
                      top: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_notificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Thông báo',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.user),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}
