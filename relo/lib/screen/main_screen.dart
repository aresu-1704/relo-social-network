// Màn hình chính với AppBar có thanh tìm kiếm, Bottom Bar, và banner mất kết nối
import 'package:flutter/material.dart';
import 'package:relo/screen/profile_screen.dart';
import 'package:relo/screen/profile_setting_screen.dart';
import 'package:relo/screen/search_screen.dart';
import 'messages_screen.dart';
import 'friends_screen.dart';
import 'newsfeed_screen.dart';
import 'notifications_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:relo/providers/notification_provider.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
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
      const NotificationsScreen(), // Notifications (3)
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

      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (int i) {
                setState(() {
                  _selectedIndex = i;
                  if (i == 3) {
                    // Mark all notifications as read when opening notifications tab
                    final notificationProvider =
                        Provider.of<NotificationProvider>(
                          context,
                          listen: false,
                        );
                    if (notificationProvider.hasUnread) {
                      notificationProvider.markAllAsRead();
                    }
                  }
                });
              },
              selectedItemColor: const Color(0xFF7A2FC0),
              unselectedItemColor: Colors.grey[600],
              backgroundColor: Colors.white,
              elevation: 8,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
                  ),
                  label: 'Tường nhà',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 1 ? Icons.people : Icons.people_outline,
                  ),
                  label: 'Bạn bè',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 2
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                  ),
                  label: 'Tin nhắn',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        _selectedIndex == 3
                            ? Icons.notifications
                            : Icons.notifications_outlined,
                      ),
                      Consumer<NotificationProvider>(
                        builder: (context, notificationProvider, child) {
                          final unreadCount = notificationProvider.unreadCount;
                          if (unreadCount > 0) {
                            return Positioned(
                              right: -8,
                              top: -8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  label: 'Thông báo',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 4 ? Icons.person : Icons.person_outline,
                  ),
                  label: 'Cá nhân',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
