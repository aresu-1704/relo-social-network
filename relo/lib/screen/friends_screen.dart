import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/models/user.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/secure_storage_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late Future<List<User>> _friendsFuture;
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  int requestCount = 0;

  bool _allImagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _userService.getFriends();
  }

  Map<String, List<User>> _groupFriends(List<User> friends) {
    friends.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    final Map<String, List<User>> groupedFriends = {};
    for (var friend in friends) {
      if (friend.displayName.isNotEmpty) {
        final firstLetter = friend.displayName[0].toUpperCase();
        groupedFriends.putIfAbsent(firstLetter, () => []).add(friend);
      }
    }
    return groupedFriends;
  }

  Future<void> _preloadAllImages(List<User> friends) async {
    List<Future> tasks = [];
    for (var friend in friends) {
      if (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty) {
        final image = NetworkImage(friend.avatarUrl!);
        tasks.add(precacheImage(image, context));
      }
    }
    await Future.wait(tasks);
    setState(() {
      _allImagesLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _allImagesLoaded = false;
            _friendsFuture = _userService.getFriends();
          });
        },
        child: FutureBuilder<List<User>>(
          future: _friendsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }

            if (snapshot.hasError || snapshot.data == null) {
              return const Center(
                child: Text("Không thể tải danh sách bạn bè"),
              );
            }

            final friends = snapshot.data!;
            if (!_allImagesLoaded) {
              _preloadAllImages(friends);
              return _buildShimmerList();
            }

            final groupedFriends = _groupFriends(friends);
            final sortedKeys = groupedFriends.keys.toList()..sort();

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final letter = sortedKeys[index];
                final friendsInGroup = groupedFriends[letter]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...friendsInGroup.map((friend) => _buildFriendTile(friend)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  '   Bạn bè',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE7F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.group,
                            color: Color(0xFF7A2FC0),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Lời mời kết bạn',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (requestCount > 0)
                                Text(
                                  '($requestCount)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(User friend) {
    return InkWell(
      onTap: () async {
        try {
          // Get current user ID
          final SecureStorageService secureStorage =
              const SecureStorageService();
          final currentUserId = await secureStorage.getUserId();

          final conversation = await _messageService.getOrCreateConversation(
            [currentUserId!, friend.id],
            false,
            null,
          );

          if (conversation.isEmpty || conversation['id'] == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Không thể tạo cuộc trò chuyện")),
            );
            return;
          }

          final participants = (conversation['participants'] ?? []) as List;

          // Extract member IDs from participants
          List<String> memberIds = [];
          if (participants.isNotEmpty) {
            for (var p in participants) {
              if (p is Map) {
                String? id = p['id']?.toString() ?? p['userId']?.toString();
                if (id != null && id.isNotEmpty) {
                  memberIds.add(id);
                }
              } else if (p is String) {
                memberIds.add(p);
              }
            }
          }

          // Fallback to friend.id if no participants found
          if (memberIds.isEmpty) {
            memberIds = [friend.id];
          }

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conversation['id'],
                isGroup: false,
                chatName: friend.displayName,
                memberIds: memberIds,
                onUserBlocked: (blockedUserId) {
                  // Xóa user khỏi danh sách bạn bè và refresh
                  setState(() {
                    _friendsFuture = _userService.getFriends();
                  });
                },
              ),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Lỗi khi mở chat: $e")));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                  ? NetworkImage(friend.avatarUrl!)
                  : null,
              child: friend.avatarUrl == null || friend.avatarUrl!.isEmpty
                  ? Text(
                      friend.displayName.isNotEmpty
                          ? friend.displayName[0].toUpperCase()
                          : '#',
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                friend.displayName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: Colors.grey),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: Colors.grey),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  // Hiệu ứng shimmer khi đang tải dữ liệu hoặc ảnh
  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListTile(
          leading: const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
          ),
          title: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          subtitle: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
    );
  }
}
