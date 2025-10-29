import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/screen/profile_screen.dart';
import 'dart:async';
import 'dart:convert';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  _FriendRequestsScreenState createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  late Future<List<Map<String, dynamic>>> _pendingRequestsFuture;
  final UserService _userService = ServiceLocator.userService;
  List<Map<String, dynamic>> _requests = [];
  StreamSubscription? _webSocketSubscription;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  void _listenToWebSocket() {
    _webSocketSubscription = webSocketService.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'friend_request_received') {
          // Reload requests when a new friend request is received
          _loadRequests();
        }
      } catch (e) {
        print('Error parsing WebSocket message: $e');
      }
    });
  }

  void _loadRequests() {
    setState(() {
      _pendingRequestsFuture = _userService.getPendingFriendRequests();
    });
  }

  Future<void> _handleResponse(String requestId, String response) async {
    try {
      await _userService.respondToFriendRequest(requestId, response);

      // Remove the accepted/rejected request from the list
      if (mounted) {
        setState(() {
          _requests.removeWhere((r) => r['id'] == requestId);
        });
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(context, 'Lỗi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A2FC0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Lời mời kết bạn',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingRequestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text("Không thể tải danh sách lời mời"));
          }

          _requests = snapshot.data!;
          if (_requests.isEmpty) {
            return const Center(child: Text("Không có lời mời kết bạn nào"));
          }

          return ListView.builder(
            itemCount: _requests.length,
            itemBuilder: (context, index) {
              final request = _requests[index];
              final fromUser = request['fromUser'] as Map<String, dynamic>?;

              if (fromUser == null) {
                return const SizedBox.shrink();
              }

              final fallbackAvatarUrl = 'assets/none_images/avatar.jpg';
              final avatarUrl = fromUser['avatarUrl'] as String?;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        // Navigate to profile screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfileScreen(userId: fromUser['id']),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                ? (avatarUrl.startsWith('assets/')
                                      ? AssetImage(avatarUrl)
                                      : NetworkImage(avatarUrl))
                                : AssetImage(fallbackAvatarUrl)
                                      as ImageProvider,
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fromUser['displayName'] ?? 'Người dùng',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${fromUser['username'] ?? ''}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _handleResponse(request['id'], 'accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF7A2FC0),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Chấp nhận',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _handleResponse(request['id'], 'reject'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Từ chối',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
